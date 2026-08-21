import PencilKit
import SwiftUI
import UIKit

extension PencilCanvasView.Coordinator {
    func scheduleRecognition(in canvasView: PKCanvasView) {
        // Always cancel here, rather than relying on every call site to
        // have already done it — canvasViewDidEndUsingTool calls this
        // directly, and a stray uncancelled timer from an earlier,
        // smaller snapshot of the drawing is exactly what fires
        // recognition on a single letter instead of the whole word.
        pendingRecognitionWorkItem?.cancel()
        guard recognitionSettings.isAutoConvertEnabled else { return }

        recognitionGeneration += 1
        let generation = recognitionGeneration
        let drawing = canvasView.drawing
        let shapeSnappedIDs = snappedStrokeIDs
        let style = fontSettings.defaultStyle

        let workItem = DispatchWorkItem { [weak self, weak canvasView] in
            guard let self, let canvasView else { return }
            Task { @MainActor in
                let textObjects = await self.recognitionWorkflow.process(
                    drawing: drawing,
                    shapeSnappedStrokeIDs: shapeSnappedIDs,
                    style: style
                )
                // The recognizer call is itself async and can outlast a
                // newer attempt getting scheduled — applying a superseded
                // result here would fragment a word into partial slices.
                guard self.recognitionGeneration == generation else { return }
                for object in textObjects {
                    self.applyRecognizedText(object, in: canvasView)
                }
            }
        }
        pendingRecognitionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.recognitionDebounceDelay, execute: workItem)
    }

    func applyRecognizedText(_ object: RecognizedTextObject, in canvasView: PKCanvasView) {
        // The recognized strokes must still all be present in the
        // current drawing — if the user kept writing (or erased
        // something) during the debounce window, this stale result is
        // discarded rather than removing strokes that no longer match
        // what was actually recognized.
        let currentIDs = Set(canvasView.drawing.strokes.map(\.id))
        guard object.sourceStrokeIDs.isSubset(of: currentIDs) else { return }

        isApplyingRecognitionUpdate = true
        let remaining = canvasView.drawing.strokes.filter { !object.sourceStrokeIDs.contains($0.id) }
        canvasView.drawing = PKDrawing(strokes: remaining)
        isApplyingRecognitionUpdate = false

        // A word/range selected via double-tap or hold turns the *next*
        // handwriting recognized anywhere on the page into a replacement
        // for that selection instead of a new, separate text object —
        // one-shot, so it's cleared immediately once used here.
        if let selection = activeWordSelection {
            activeWordSelection = nil
            if let existing = textStore.textObjects.first(where: { $0.id == selection.id }) {
                if let updated = TextEditCommit.replacing(range: selection.range, in: existing, with: object.text) {
                    applyTextReplacement(updated, id: selection.id)
                } else {
                    deleteTextObject(id: selection.id)
                }
            }
            return
        }

        textStore.add(object)
        addTextOverlay(for: object)
    }

    func addTextOverlay(for object: RecognizedTextObject) {
        guard let pageContainer else { return }
        let textView = RecognizedTextView()
        textView.attributedText = AttributedTextRenderer.render(object, using: availabilityService)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.isEditable = false
        // Off at rest and while whole-object selected (see selectTextObject)
        // — only turned on for the brief window a word/range selection is
        // actually active (see beginWordSelection). Leaving it on all the
        // time let UITextView's own native hold-to-select-and-drag gesture
        // compete with — and reliably beat — the custom pan gesture used
        // for whole-object move, which is why word selection here is
        // driven by our own tap/long-press gestures (WordBoundaryFinder)
        // rather than UITextView's built-in double-tap-to-select-word.
        textView.isSelectable = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isUserInteractionEnabled = true
        textView.delegate = self
        // UITextView inherits UIScrollView's own pan gesture for content
        // scrolling — harmless while isScrollEnabled is false, but it still
        // competes with `handleTextPan` below for the same touches and was
        // silently swallowing whole-object drag-to-move. Disabling it here
        // (once, unconditionally — scrolling is never used) is what actually
        // fixes drag, not anything about selection state.
        textView.panGestureRecognizer.isEnabled = false
        sizeTextView(textView, for: object)

        // Only active once selected via a single tap — otherwise a finger
        // drag anywhere on the text view would fight the page's own
        // finger-pan-to-scroll gesture before the user ever asked to move it.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleTextPan(_:)))
        pan.isEnabled = false
        textView.addGestureRecognizer(pan)

        // Fires immediately on tap-up, no delay — deliberately *not*
        // `require(toFail:)`'d against the double-tap/long-press gestures
        // below. That would only recognize once the double-tap window
        // timed out, and a real single-tap-then-immediately-drag (the
        // normal way to select-then-move something) would start dragging
        // before this gesture had even resolved, losing the touch to
        // whichever gesture wins that race — which is exactly what made
        // move unreliable before. The one accepted tradeoff: the first tap
        // of a genuine double-tap also fires this for an instant before
        // the word-select gestures below take over and supersede it.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTextTap(_:)))
        textView.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleWordSelectGesture(_:)))
        doubleTap.numberOfTapsRequired = 2
        textView.addGestureRecognizer(doubleTap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleWordSelectGesture(_:)))
        textView.addGestureRecognizer(longPress)

        pageContainer.addSubview(textView)
        textViewsByID[object.id] = textView
    }

    /// `object.boundingBox` (from `TextPositioningService`) supplies the
    /// horizontal origin and the vertical *center* — not anchoring to the
    /// raw stroke union, which is often looser than the glyphs it becomes
    /// and would block Pencil input well past where the text actually
    /// sits. Its height is only an estimate, though, and was found too
    /// tight for real font metrics (Noteworthy Bold's `g`/`y` descenders
    /// clipped at the bottom on-device) — `sizeThatFits` already computes
    /// the actual height that font needs, so the taller of the two wins,
    /// keeping the same vertical center either way.
    private func sizeTextView(_ textView: UITextView, for object: RecognizedTextObject) {
        let unconstrained = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let natural = textView.sizeThatFits(unconstrained)
        let height = max(object.boundingBox.height, natural.height)
        textView.frame = CGRect(
            x: object.boundingBox.origin.x,
            y: object.boundingBox.midY - height / 2,
            width: natural.width,
            height: height
        )
    }

    /// Used after a replace or a font/size change, where the text view
    /// already has a real on-page position — re-derives only the size
    /// needed for the (possibly now different) text, keeping the existing
    /// horizontal origin and vertical center rather than re-anchoring to
    /// the original handwriting geometry.
    func resizeToFitCurrentText(_ textView: UITextView) {
        let unconstrained = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let natural = textView.sizeThatFits(unconstrained)
        let height = max(natural.height, textView.frame.height)
        let minX = textView.frame.minX
        let midY = textView.frame.midY
        textView.frame = CGRect(x: minX, y: midY - height / 2, width: natural.width, height: height)
    }

    func syncBoundingBox(for id: UUID, frame: CGRect) {
        guard var object = textStore.textObjects.first(where: { $0.id == id }) else { return }
        object.boundingBox = frame
        textStore.update(object)
    }

    /// Finger taps on a text view are unaffected by canvasView's `.pencilOnly`
    /// drawing policy — that policy only governs which touches canvasView
    /// itself treats as ink, not what a sibling view's own gesture
    /// recognizer receives.
    @objc func handleTextTap(_ gesture: UITapGestureRecognizer) {
        guard let textView = gesture.view as? UITextView,
              let id = textViewsByID.first(where: { $0.value === textView })?.key else { return }
        selectTextObject(id: id)
    }

    /// A single tap selects the *whole* object — blue border, draggable —
    /// distinct from double-tap/hold (`handleWordSelectGesture`), which
    /// select just a word/range instead.
    func selectTextObject(id: UUID) {
        deselectTextObject()
        clearActiveWordSelection()
        guard let textView = textViewsByID[id], let pageContainer else { return }
        selectedTextObjectID = id
        textView.layer.borderColor = UIColor.systemBlue.cgColor
        textView.layer.borderWidth = 1.5
        textView.layer.cornerRadius = 4
        panGesture(on: textView)?.isEnabled = true
        showToolbar(for: id, replaceRange: nil, in: pageContainer)
    }

    func deselectTextObject() {
        guard let id = selectedTextObjectID else { return }
        if let textView = textViewsByID[id] {
            textView.layer.borderWidth = 0
            panGesture(on: textView)?.isEnabled = false
        }
        selectedTextObjectID = nil
        hideToolbarIfOwned(by: id)
    }

    /// Called when tapping outside all text objects — clears whichever
    /// object currently has a word/range selection active (there's at
    /// most one at a time), since that selection has its own visual
    /// highlight independent of `selectedTextObjectID`.
    func clearActiveWordSelection() {
        activeWordSelection = nil
        for (id, textView) in textViewsByID where textView.selectedRange.length > 0 {
            textView.selectedRange = NSRange(location: 0, length: 0)
            if textView.isFirstResponder {
                textView.resignFirstResponder()
            }
            textView.isSelectable = false
            hideToolbarIfOwned(by: id)
        }
    }

    /// Double-tap or hold-to-select a word, driven by our own gestures and
    /// `WordBoundaryFinder` rather than UITextView's built-in word-select —
    /// see the comment on `isSelectable` in `addTextOverlay` for why.
    /// `isSelectable` is turned on only for this selection's lifetime, so
    /// its own native selection handles (drag left/right to extend across
    /// more words) and Copy/Look Up menu still work exactly as they would
    /// natively — this only replaces *how* the initial word gets picked.
    @objc func handleWordSelectGesture(_ gesture: UIGestureRecognizer) {
        if let longPress = gesture as? UILongPressGestureRecognizer, longPress.state != .began { return }
        guard let textView = gesture.view as? UITextView,
              let id = textViewsByID.first(where: { $0.value === textView })?.key else { return }

        let point = gesture.location(in: textView)
        guard let position = textView.closestPosition(to: point) else { return }
        let offset = textView.offset(from: textView.beginningOfDocument, to: position)
        guard let wordRange = WordBoundaryFinder.wordRange(in: textView.text, at: offset) else { return }

        deselectTextObject()
        textView.isSelectable = true
        textView.selectedRange = wordRange
        textView.becomeFirstResponder()
    }

    /// Fires for both the initial word selection above and for the user
    /// dragging its native handles to extend the selection across more
    /// words — either way, keeps the toolbar's target range current.
    func textViewDidChangeSelection(_ textView: UITextView) {
        guard let id = textViewsByID.first(where: { $0.value === textView })?.key,
              let pageContainer else { return }

        guard textView.selectedRange.length > 0 else {
            activeWordSelection = nil
            hideToolbarIfOwned(by: id)
            return
        }
        activeWordSelection = (id: id, range: textView.selectedRange)
        showToolbar(for: id, replaceRange: textView.selectedRange, in: pageContainer)
    }

    @objc func handleTextPan(_ gesture: UIPanGestureRecognizer) {
        guard let textView = gesture.view as? UITextView,
              let id = textViewsByID.first(where: { $0.value === textView })?.key,
              let pageContainer else { return }

        let translation = gesture.translation(in: pageContainer)
        textView.frame.origin.x += translation.x
        textView.frame.origin.y += translation.y
        gesture.setTranslation(.zero, in: pageContainer)

        guard gesture.state == .ended || gesture.state == .cancelled,
              var object = textStore.textObjects.first(where: { $0.id == id }) else { return }
        object.boundingBox.origin = textView.frame.origin
        textStore.update(object)
    }

    /// `UITextView` is a `UIScrollView` subclass and already carries its
    /// own built-in `panGestureRecognizer` for scrolling — present in
    /// `gestureRecognizers` (just disabled) alongside the custom one added
    /// in `addTextOverlay`. Picking `.first` without excluding it was
    /// finding *that* one, so every enable/disable call here was toggling
    /// the wrong gesture and the real move gesture never actually turned
    /// on — the actual reason drag-to-move silently never worked.
    func panGesture(on textView: UITextView) -> UIPanGestureRecognizer? {
        textView.gestureRecognizers?
            .compactMap { $0 as? UIPanGestureRecognizer }
            .first { $0 !== textView.panGestureRecognizer }
    }

    func deleteTextObject(id: UUID) {
        deselectTextObject()
        hideToolbarIfOwned(by: id)
        textViewsByID[id]?.removeFromSuperview()
        textViewsByID.removeValue(forKey: id)
        textStore.remove(id: id)
    }
}

/// A plain `UITextView` sits above `PKCanvasView` in `pageContainer` and would
/// otherwise claim every touch inside its frame during hit-testing — including
/// Pencil touches — before `canvasView` ever sees them, making it impossible
/// to write over or directly below converted text. `.pencilOnly` only governs
/// what `canvasView` itself treats as ink; it has no effect on a sibling
/// view's hit-testing. Letting Pencil touches fall through here restores
/// normal drawing while finger taps still reach the text view for select/
/// word-select, and native selection brings Copy along for free.
final class RecognizedTextView: UITextView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if event?.allTouches?.contains(where: { $0.type == .pencil }) == true {
            return nil
        }
        return super.hitTest(point, with: event)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let fitted = sizeThatFits(CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude))
        contentInset.top = max(0, (bounds.height - fitted.height) / 2)
    }
}
