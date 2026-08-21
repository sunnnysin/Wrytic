import Foundation
import PencilKit
import UIKit

extension PencilCanvasView.Coordinator {
    func select(strokeID: UUID, fit: ShapeFit, originalStroke: PKStroke, in canvasView: PKCanvasView) {
        guard let pageContainer else { return }

        selectedStrokeID = strokeID
        selectedFit = fit
        selectedOriginalStroke = originalStroke
        selectedOriginalPoints = Array(originalStroke.path)
        activeCanvasView = canvasView

        let overlay = selectionOverlay ?? makeSelectionOverlay(in: pageContainer)
        overlay.update(boundingBox: fit.boundingBox)
    }

    private func makeSelectionOverlay(in pageContainer: UIView) -> ShapeSelectionOverlayView {
        let overlay = ShapeSelectionOverlayView()
        overlay.onMove = { [weak self] translation in
            self?.applySelectionUpdate { fit in fit.translated(by: translation) }
        }
        overlay.onResize = { [weak self] newCorner in
            self?.applySelectionUpdate { fit in fit.resized(draggingCornerTo: newCorner) }
        }
        overlay.onGestureEnded = { [weak self] in
            self?.dragStartFit = nil
        }
        pageContainer.addSubview(overlay)
        selectionOverlay = overlay
        return overlay
    }

    private func applySelectionUpdate(_ transform: (ShapeFit) -> ShapeFit) {
        guard let baseFit = dragStartFit ?? selectedFit,
              let canvasView = activeCanvasView,
              let strokeID = selectedStrokeID,
              let originalStroke = selectedOriginalStroke,
              let index = canvasView.drawing.strokes.firstIndex(where: { $0.id == strokeID }) else { return }
        if dragStartFit == nil { dragStartFit = selectedFit }

        let newFit = transform(baseFit)
        let newStroke = ShapeSnapService.buildStroke(
            for: newFit,
            matching: originalStroke,
            originalPoints: selectedOriginalPoints
        )

        isApplyingSelectionUpdate = true
        var strokes = canvasView.drawing.strokes
        strokes[index] = newStroke
        canvasView.drawing = PKDrawing(strokes: strokes)
        isApplyingSelectionUpdate = false

        selectedStrokeID = newStroke.id
        selectedFit = newFit
        selectionOverlay?.update(boundingBox: newFit.boundingBox)
    }

    @objc func handleDeselectTap(_ gesture: UITapGestureRecognizer) {
        guard let pageContainer else { return }
        let location = gesture.location(in: pageContainer)

        if let overlay = selectionOverlay {
            if overlay.resizeHandleFrameInSuperview.insetBy(dx: -8, dy: -8).contains(location) {
                return
            }
            let tolerance = PencilCanvasView.Coordinator.shapeSelectionTapTolerance
            if let fit = selectedFit, fit.isNear(location, tolerance: tolerance) {
                return
            }
        }
        if let overlay = imageSelectionOverlay, overlay.frame.insetBy(dx: -8, dy: -8).contains(location) {
            return
        }
        // The toolbar and replace box live directly on the screen's
        // root view, above pageContainer in z-order — a tap on either
        // is hit-tested to them first and never reaches this gesture
        // recognizer at all, so no explicit exclusion check is needed
        // for them here (unlike the text view itself, which is a
        // pageContainer subview at the same level this gesture runs on).
        if let selectedTextObjectID, let textView = textViewsByID[selectedTextObjectID],
           textView.frame.insetBy(dx: -8, dy: -8).contains(location) {
            return
        }
        deselect()
        deselectTextObject()
        clearActiveWordSelection()
        // Images render below canvasView so ink naturally draws on top
        // of them (see PencilCanvasView+Images.swift) — that means an
        // image never receives touches directly, so tap-to-select has
        // to be resolved here, against the stored objects' frames,
        // rather than via a gesture recognizer on the image view itself.
        if let hit = imageStore.imageObjects.last(where: { $0.frame.contains(location) }) {
            selectImage(id: hit.id)
        } else {
            deselectImage()
        }
    }

    private func deselect() {
        selectionOverlay?.removeFromSuperview()
        selectionOverlay = nil
        selectedStrokeID = nil
        selectedFit = nil
        selectedOriginalStroke = nil
        selectedOriginalPoints = []
        dragStartFit = nil
    }
}
