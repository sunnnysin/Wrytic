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

        textStore.add(object)
        addTextOverlay(for: object)
    }

    func addTextOverlay(for object: RecognizedTextObject) {
        guard let pageContainer else { return }
        let textView = RecognizedTextView()
        textView.text = object.text
        textView.font = availabilityService.resolvedUIFont(
            for: object.style.font,
            weight: object.style.weight,
            size: object.style.size
        )
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isUserInteractionEnabled = true
        textView.delegate = self
        sizeTextView(textView, for: object)

        // Only active once selected (see selectTextObject) — otherwise a
        // finger drag anywhere on the text view would fight the page's own
        // finger-pan-to-scroll gesture before the user ever asked to move it.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleTextPan(_:)))
        pan.isEnabled = false
        textView.addGestureRecognizer(pan)
        // Disabled once editing begins, so UITextView's own tap-to-place-
        // cursor handles subsequent taps instead of fighting this one.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTextTap(_:)))
        textView.addGestureRecognizer(tap)

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

    /// Used after an edit or a font/size change, where the text view
    /// already has a real on-page position — re-derives only the size
    /// needed for the (possibly now different) text, keeping the existing
    /// horizontal origin and vertical center rather than re-anchoring to
    /// the original handwriting geometry.
    private func resizeToFitCurrentText(_ textView: UITextView) {
        let unconstrained = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let natural = textView.sizeThatFits(unconstrained)
        let height = max(natural.height, textView.frame.height)
        let minX = textView.frame.minX
        let midY = textView.frame.midY
        textView.frame = CGRect(x: minX, y: midY - height / 2, width: natural.width, height: height)
    }

    private func syncBoundingBox(for id: UUID, frame: CGRect) {
        guard var object = textStore.textObjects.first(where: { $0.id == id }) else { return }
        object.boundingBox = frame
        textStore.update(object)
    }

    /// Finger taps on a text view are unaffected by canvasView's `.pencilOnly`
    /// drawing policy — that policy only governs which touches canvasView
    /// itself treats as ink, not what a sibling view's own gesture
    /// recognizer receives. Erasing converted text with the Pencil eraser
    /// tool was tried first and dropped: PKCanvasView claims Pencil touches
    /// for its own internal stroke handling, and a competing gesture
    /// recognizer fighting it for the same touches is exactly the kind of
    /// conflict PencilKit apps are documented to avoid.
    @objc func handleTextTap(_ gesture: UITapGestureRecognizer) {
        guard let textView = gesture.view as? UITextView,
              let id = textViewsByID.first(where: { $0.value === textView })?.key else { return }
        if selectedTextObjectID == id {
            beginEditingTextObject(id: id)
        } else {
            selectTextObject(id: id)
        }
    }

    func selectTextObject(id: UUID) {
        deselectTextObject()
        guard let textView = textViewsByID[id], let pageContainer else { return }
        selectedTextObjectID = id
        textView.layer.borderColor = UIColor.systemBlue.cgColor
        textView.layer.borderWidth = 1.5
        textView.layer.cornerRadius = 4
        panGesture(on: textView)?.isEnabled = true

        let deleteButton = UIButton(type: .system)
        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.backgroundColor = .systemBackground
        deleteButton.layer.cornerRadius = 11
        deleteButton.addTarget(self, action: #selector(handleDeleteButtonTap(_:)), for: .touchUpInside)
        pageContainer.addSubview(deleteButton)
        deleteButtonsByID[id] = deleteButton

        let fontButton = UIButton(type: .system)
        fontButton.setImage(UIImage(systemName: "textformat"), for: .normal)
        fontButton.tintColor = .label
        fontButton.backgroundColor = .systemBackground
        fontButton.layer.cornerRadius = 11
        fontButton.addTarget(self, action: #selector(handleFontButtonTap(_:)), for: .touchUpInside)
        pageContainer.addSubview(fontButton)
        fontButtonsByID[id] = fontButton

        repositionOverlayButtons(for: id)
    }

    func deselectTextObject() {
        guard let id = selectedTextObjectID else { return }
        if let textView = textViewsByID[id] {
            if textView.isFirstResponder {
                textView.resignFirstResponder()
            }
            textView.layer.borderWidth = 0
            panGesture(on: textView)?.isEnabled = false
        }
        deleteButtonsByID[id]?.removeFromSuperview()
        deleteButtonsByID.removeValue(forKey: id)
        fontButtonsByID[id]?.removeFromSuperview()
        fontButtonsByID.removeValue(forKey: id)
        selectedTextObjectID = nil
    }

    func beginEditingTextObject(id: UUID) {
        guard let textView = textViewsByID[id] else { return }
        editingTextObjectID = id
        panGesture(on: textView)?.isEnabled = false
        tapGesture(on: textView)?.isEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.becomeFirstResponder()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        guard let id = textViewsByID.first(where: { $0.value === textView })?.key else { return }
        editingTextObjectID = nil
        textView.isEditable = false
        textView.isSelectable = false
        tapGesture(on: textView)?.isEnabled = true
        if selectedTextObjectID == id {
            panGesture(on: textView)?.isEnabled = true
        }

        guard let object = textStore.textObjects.first(where: { $0.id == id }) else { return }
        guard let updated = TextEditCommit.apply(editedText: textView.text, to: object) else {
            deleteTextObject(id: id)
            return
        }
        textStore.update(updated)
        textView.text = updated.text
        resizeToFitCurrentText(textView)
        syncBoundingBox(for: id, frame: textView.frame)
        repositionOverlayButtons(for: id)
    }

    @objc func handleDeleteButtonTap(_ sender: UIButton) {
        guard let id = deleteButtonsByID.first(where: { $0.value === sender })?.key else { return }
        deleteTextObject(id: id)
    }

    @objc func handleFontButtonTap(_ sender: UIButton) {
        guard let id = fontButtonsByID.first(where: { $0.value === sender })?.key else { return }
        presentFontPicker(for: id, anchoredTo: sender)
    }

    private func presentFontPicker(for id: UUID, anchoredTo anchorView: UIView) {
        guard let hostViewController = anchorView.parentViewController else { return }
        let binding = Binding<TextStyle>(
            get: { [weak self] in
                self?.textStore.textObjects.first(where: { $0.id == id })?.style ?? .default
            },
            set: { [weak self] newStyle in
                self?.applyStyleChange(newStyle, to: id)
            }
        )
        let picker = UIHostingController(rootView: NavigationStack { FontPickerView(style: binding) })
        picker.modalPresentationStyle = .popover
        picker.preferredContentSize = CGSize(width: 320, height: 420)
        picker.popoverPresentationController?.sourceView = anchorView
        picker.popoverPresentationController?.sourceRect = anchorView.bounds
        hostViewController.present(picker, animated: true)
    }

    private func applyStyleChange(_ style: TextStyle, to id: UUID) {
        guard var object = textStore.textObjects.first(where: { $0.id == id }),
              let textView = textViewsByID[id] else { return }
        object.style = style
        textStore.update(object)
        textView.font = availabilityService.resolvedUIFont(for: style.font, weight: style.weight, size: style.size)
        resizeToFitCurrentText(textView)
        syncBoundingBox(for: id, frame: textView.frame)
        repositionOverlayButtons(for: id)
    }

    @objc func handleTextPan(_ gesture: UIPanGestureRecognizer) {
        guard let textView = gesture.view as? UITextView,
              let id = textViewsByID.first(where: { $0.value === textView })?.key,
              let pageContainer else { return }

        let translation = gesture.translation(in: pageContainer)
        textView.frame.origin.x += translation.x
        textView.frame.origin.y += translation.y
        gesture.setTranslation(.zero, in: pageContainer)
        repositionOverlayButtons(for: id)

        guard gesture.state == .ended || gesture.state == .cancelled,
              var object = textStore.textObjects.first(where: { $0.id == id }) else { return }
        object.boundingBox.origin = textView.frame.origin
        textStore.update(object)
    }

    private func panGesture(on textView: UITextView) -> UIPanGestureRecognizer? {
        textView.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }.first
    }

    private func tapGesture(on textView: UITextView) -> UITapGestureRecognizer? {
        textView.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.first
    }

    private func repositionOverlayButtons(for id: UUID) {
        guard let textView = textViewsByID[id] else { return }
        if let deleteButton = deleteButtonsByID[id] {
            deleteButton.frame = CGRect(x: textView.frame.maxX - 11, y: textView.frame.minY - 11, width: 22, height: 22)
        }
        if let fontButton = fontButtonsByID[id] {
            fontButton.frame = CGRect(x: textView.frame.maxX - 33, y: textView.frame.minY - 11, width: 22, height: 22)
        }
    }

    func deleteTextObject(id: UUID) {
        deselectTextObject()
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
/// edit, and (once editing) native cursor placement, selection, and copy/
/// paste all come from UITextView itself rather than being rebuilt by hand.
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
