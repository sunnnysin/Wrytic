import PencilKit
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
        let label = RecognizedTextLabel()
        label.text = object.text
        label.font = availabilityService.resolvedUIFont(
            for: object.style.font,
            weight: object.style.weight,
            size: object.style.size
        )
        label.numberOfLines = 0
        sizeLabel(label, for: object)
        label.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTextTap(_:)))
        label.addGestureRecognizer(tap)
        // Only active once selected (see selectTextObject) — otherwise a
        // finger drag anywhere on the label would fight the page's own
        // finger-pan-to-scroll gesture before the user ever asked to move it.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleTextPan(_:)))
        pan.isEnabled = false
        label.addGestureRecognizer(pan)
        pageContainer.addSubview(label)
        textLabelsByID[object.id] = label
    }

    /// `object.boundingBox` (from `TextPositioningService`) supplies the
    /// horizontal origin and the vertical *center* — not anchoring to the
    /// raw stroke union, which is often looser than the glyphs it becomes
    /// and would block Pencil input well past where the text actually
    /// sits. Its height is only an estimate, though, and was found too
    /// tight for real font metrics (Noteworthy Bold's `g`/`y` descenders
    /// clipped at the bottom on-device) — `label.sizeToFit()` already
    /// computes the actual height that font needs, so the taller of the
    /// two wins, keeping the same vertical center either way.
    private func sizeLabel(_ label: UILabel, for object: RecognizedTextObject) {
        label.sizeToFit()
        let height = max(object.boundingBox.height, label.frame.height)
        label.frame = CGRect(
            x: object.boundingBox.origin.x,
            y: object.boundingBox.midY - height / 2,
            width: label.frame.width,
            height: height
        )
    }

    /// Finger taps on a label are unaffected by canvasView's `.pencilOnly`
    /// drawing policy — that policy only governs which touches canvasView
    /// itself treats as ink, not what a sibling view's own gesture
    /// recognizer receives. Erasing converted text with the Pencil eraser
    /// tool was tried first and dropped: PKCanvasView claims Pencil touches
    /// for its own internal stroke handling, and a competing gesture
    /// recognizer fighting it for the same touches is exactly the kind of
    /// conflict PencilKit apps are documented to avoid.
    @objc func handleTextTap(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let id = textLabelsByID.first(where: { $0.value === label })?.key else { return }
        if selectedTextObjectID == id {
            deleteTextObject(id: id)
        } else {
            selectTextObject(id: id)
        }
    }

    func selectTextObject(id: UUID) {
        deselectTextObject()
        guard let label = textLabelsByID[id], let pageContainer else { return }
        selectedTextObjectID = id
        label.layer.borderColor = UIColor.systemBlue.cgColor
        label.layer.borderWidth = 1.5
        label.layer.cornerRadius = 4
        panGesture(on: label)?.isEnabled = true

        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .systemRed
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 11
        button.addTarget(self, action: #selector(handleDeleteButtonTap(_:)), for: .touchUpInside)
        pageContainer.addSubview(button)
        deleteButtonsByID[id] = button
        repositionDeleteButton(for: id)
    }

    func deselectTextObject() {
        guard let id = selectedTextObjectID else { return }
        if let label = textLabelsByID[id] {
            label.layer.borderWidth = 0
            panGesture(on: label)?.isEnabled = false
        }
        deleteButtonsByID[id]?.removeFromSuperview()
        deleteButtonsByID.removeValue(forKey: id)
        selectedTextObjectID = nil
    }

    @objc func handleDeleteButtonTap(_ sender: UIButton) {
        guard let id = deleteButtonsByID.first(where: { $0.value === sender })?.key else { return }
        deleteTextObject(id: id)
    }

    @objc func handleTextPan(_ gesture: UIPanGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let id = textLabelsByID.first(where: { $0.value === label })?.key,
              let pageContainer else { return }

        let translation = gesture.translation(in: pageContainer)
        label.frame.origin.x += translation.x
        label.frame.origin.y += translation.y
        gesture.setTranslation(.zero, in: pageContainer)
        repositionDeleteButton(for: id)

        guard gesture.state == .ended || gesture.state == .cancelled,
              var object = textStore.textObjects.first(where: { $0.id == id }) else { return }
        object.boundingBox.origin = label.frame.origin
        textStore.update(object)
    }

    private func panGesture(on label: UILabel) -> UIPanGestureRecognizer? {
        label.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }.first
    }

    private func repositionDeleteButton(for id: UUID) {
        guard let label = textLabelsByID[id], let button = deleteButtonsByID[id] else { return }
        button.frame = CGRect(x: label.frame.maxX - 11, y: label.frame.minY - 11, width: 22, height: 22)
    }

    func deleteTextObject(id: UUID) {
        deselectTextObject()
        textLabelsByID[id]?.removeFromSuperview()
        textLabelsByID.removeValue(forKey: id)
        textStore.remove(id: id)
    }
}

/// A plain `UILabel` sits above `PKCanvasView` in `pageContainer` and would
/// otherwise claim every touch inside its frame during hit-testing — including
/// Pencil touches — before `canvasView` ever sees them, making it impossible
/// to write over or directly below converted text. `.pencilOnly` only governs
/// what `canvasView` itself treats as ink; it has no effect on a sibling
/// view's hit-testing. Letting Pencil touches fall through here restores
/// normal drawing while finger taps still reach the label for select/delete.
final class RecognizedTextLabel: UILabel {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if event?.allTouches?.contains(where: { $0.type == .pencil }) == true {
            return nil
        }
        return super.hitTest(point, with: event)
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines: Int) -> CGRect {
        var rect = super.textRect(forBounds: bounds, limitedToNumberOfLines: limitedToNumberOfLines)
        rect.origin.y = bounds.origin.y + (bounds.height - rect.height) / 2
        return rect
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: textRect(forBounds: rect, limitedToNumberOfLines: numberOfLines))
    }
}
