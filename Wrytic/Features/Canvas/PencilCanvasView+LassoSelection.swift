import PencilKit
import SwiftUI
import UIKit

extension PencilCanvasView.Coordinator {
    private static let lassoSampleSpacing: CGFloat = 12
    private static let duplicateOffset = CGPoint(x: 32, y: 32)

    func setLassoMode(_ enabled: Bool) {
        guard enabled != isLassoModeActive else { return }
        isLassoModeActive = enabled
        if enabled {
            deselect()
            deselectTextObject()
            deselectImage()
            clearActiveWordSelection()
            pendingRecognitionWorkItem?.cancel()
            if let canvasView = canvasViewRef {
                toolPicker.setVisible(false, forFirstResponder: canvasView)
            }
            presentLassoOverlay()
        } else {
            teardownLassoSelection()
            if let canvasView = canvasViewRef {
                toolPicker.setVisible(true, forFirstResponder: canvasView)
                canvasView.becomeFirstResponder()
            }
        }
    }

    func teardownLassoSelection() {
        clearGroupSelection()
        lassoOverlay?.removeFromSuperview()
        lassoOverlay = nil
    }

    func clearGroupSelection() {
        selectionGroup = nil
        groupDragBaseline = nil
        lassoActions.isVisible = false
        lassoOverlay?.showLasso()
    }

    private func presentLassoOverlay() {
        guard let pageContainer else { return }
        let overlay = lassoOverlay ?? makeLassoOverlay(in: pageContainer)
        overlay.frame = pageContainer.bounds
        pageContainer.bringSubviewToFront(overlay)
        overlay.showLasso()
        selectionGroup = nil
        lassoActions.isVisible = false
    }

    private func makeLassoOverlay(in pageContainer: UIView) -> LassoOverlayView {
        let overlay = LassoOverlayView()
        overlay.onLassoComplete = { [weak self] loop in self?.completeLasso(loop) }
        overlay.onMove = { [weak self] translation in self?.moveGroup(by: translation) }
        overlay.onResize = { [weak self] corner in self?.resizeGroupImage(cornerTo: corner) }
        overlay.onGestureEnded = { [weak self] in self?.endGroupDrag() }
        overlay.onTapOutsideSelection = { [weak self] in self?.clearGroupSelection() }
        pageContainer.addSubview(overlay)
        lassoOverlay = overlay
        return overlay
    }

    // MARK: Selection

    func completeLasso(_ loop: [CGPoint]) {
        guard loop.count >= 3, let canvasView = canvasViewRef, let pageContainer else {
            lassoOverlay?.showLasso()
            return
        }

        let strokeIDs = matchedStrokeIDs(loop: loop, canvasView: canvasView, pageContainer: pageContainer)
        let textIDs = LassoHitTesting.selected(
            within: loop,
            from: textStore.textObjects.map {
                LassoHitTesting.Candidate(
                    id: $0.id,
                    samplePoints: LassoHitTesting.sampleRect(textFrame(for: $0.id) ?? $0.boundingBox)
                )
            }
        )
        let imageIDs = LassoHitTesting.selected(
            within: loop,
            from: imageStore.imageObjects.map {
                LassoHitTesting.Candidate(id: $0.id, samplePoints: LassoHitTesting.sampleRect($0.frame))
            }
        )

        guard !strokeIDs.isEmpty || !textIDs.isEmpty || !imageIDs.isEmpty else {
            lassoOverlay?.showLasso()
            return
        }

        let rects = groupRects(strokeIDs: strokeIDs, textIDs: textIDs, imageIDs: imageIDs)
        let group = SelectionGroup(
            strokeIDs: strokeIDs,
            textObjectIDs: textIDs,
            imageIDs: imageIDs,
            boundingBox: SelectionGroup.union(of: rects)
        )
        selectionGroup = group
        lassoOverlay?.showSelection(boundingBox: group.boundingBox, allowResize: group.resizableImageID != nil)
        lassoActions.isVisible = true
    }

    private func matchedStrokeIDs(loop: [CGPoint], canvasView: PKCanvasView, pageContainer: UIView) -> Set<UUID> {
        var matched: Set<UUID> = []
        for stroke in canvasView.drawing.strokes {
            let samples = strokeSamplePoints(stroke).map { canvasView.convert($0, to: pageContainer) }
            if LassoHitTesting.encloses(loop, samples) { matched.insert(stroke.id) }
        }
        return matched
    }

    /// Rebuilds the stroke with translated control points rather than
    /// setting `PKStroke.transform` — a transform-only change on an
    /// existing stroke isn't reliably repainted by `PKCanvasView`, the
    /// same reason Phase 7's shape move rebuilds the path.
    static func translated(_ stroke: PKStroke, by delta: CGPoint) -> PKStroke {
        let movedPoints = stroke.path.map { point in
            PKStrokePoint(
                location: CGPoint(x: point.location.x + delta.x, y: point.location.y + delta.y),
                timeOffset: point.timeOffset,
                size: point.size,
                opacity: point.opacity,
                force: point.force,
                azimuth: point.azimuth,
                altitude: point.altitude
            )
        }
        let movedPath = PKStrokePath(controlPoints: movedPoints, creationDate: stroke.path.creationDate)
        return PKStroke(ink: stroke.ink, path: movedPath, transform: stroke.transform, mask: stroke.mask, id: stroke.id)
    }

    // MARK: Move

    private func moveGroup(by translation: CGPoint) {
        guard let group = selectionGroup, let canvasView = canvasViewRef else { return }
        if groupDragBaseline == nil {
            groupDragBaseline = captureGroupBaseline(group, in: canvasView)
        }
        guard let baseline = groupDragBaseline else { return }

        var strokes = baseline.strokes
        for index in strokes.indices where baseline.movedStrokeIDs.contains(strokes[index].id) {
            strokes[index] = Self.translated(baseline.strokes[index], by: translation)
        }
        isApplyingSelectionUpdate = true
        canvasView.drawing = PKDrawing(strokes: strokes)
        isApplyingSelectionUpdate = false

        for (id, frame) in baseline.textFrames {
            textViewsByID[id]?.frame = frame.offsetBy(dx: translation.x, dy: translation.y)
        }
        for (id, frame) in baseline.imageFrames {
            imageViewsByID[id]?.frame = frame.offsetBy(dx: translation.x, dy: translation.y)
        }

        let box = baseline.boundingBox.offsetBy(dx: translation.x, dy: translation.y)
        selectionGroup?.boundingBox = box
        lassoOverlay?.updateSelection(boundingBox: box)
    }

    private func resizeGroupImage(cornerTo corner: CGPoint) {
        guard let group = selectionGroup, let id = group.resizableImageID,
              var object = imageStore.imageObjects.first(where: { $0.id == id }) else { return }
        if groupDragBaseline == nil {
            groupDragBaseline = captureGroupBaseline(group, in: canvasViewRef)
        }
        let baseFrame = groupDragBaseline?.imageFrames[id] ?? object.frame
        let aspectRatio = baseFrame.height > 0 ? baseFrame.width / baseFrame.height : 1
        let newFrame = ImageGeometry.resized(baseFrame, draggingCornerTo: corner, aspectRatio: aspectRatio)

        object.frame = newFrame
        imageStore.update(object)
        imageViewsByID[id]?.frame = newFrame
        selectionGroup?.boundingBox = newFrame
        lassoOverlay?.updateSelection(boundingBox: newFrame)
    }

    private func endGroupDrag() {
        defer { groupDragBaseline = nil }
        guard let group = selectionGroup else { return }
        for id in group.textObjectIDs {
            guard let frame = textViewsByID[id]?.frame else { continue }
            syncBoundingBox(for: id, frame: frame)
        }
        for id in group.imageIDs {
            guard var object = imageStore.imageObjects.first(where: { $0.id == id }),
                  let frame = imageViewsByID[id]?.frame else { continue }
            object.frame = frame
            imageStore.update(object)
        }
    }

    // MARK: Duplicate / delete

    func duplicateGroup() {
        guard let group = selectionGroup, let canvasView = canvasViewRef else { return }

        let newStrokeIDs = duplicateStrokes(of: group, in: canvasView)
        let newTextIDs = duplicateTextObjects(of: group)
        let newImageIDs = duplicateImages(of: group)

        if let overlay = lassoOverlay { pageContainer?.bringSubviewToFront(overlay) }

        let rects = groupRects(strokeIDs: newStrokeIDs, textIDs: newTextIDs, imageIDs: newImageIDs)
        let newGroup = SelectionGroup(
            strokeIDs: newStrokeIDs,
            textObjectIDs: newTextIDs,
            imageIDs: newImageIDs,
            boundingBox: SelectionGroup.union(of: rects)
        )
        selectionGroup = newGroup
        groupDragBaseline = nil
        lassoOverlay?.showSelection(boundingBox: newGroup.boundingBox, allowResize: newGroup.resizableImageID != nil)
    }

    private func duplicateStrokes(of group: SelectionGroup, in canvasView: PKCanvasView) -> Set<UUID> {
        var newIDs: Set<UUID> = []
        var strokes = canvasView.drawing.strokes
        for stroke in canvasView.drawing.strokes where group.strokeIDs.contains(stroke.id) {
            var copy = Self.translated(stroke, by: Self.duplicateOffset)
            copy.id = UUID()
            strokes.append(copy)
            newIDs.insert(copy.id)
            if snappedStrokeIDs.contains(stroke.id) {
                snappedStrokeIDs.insert(copy.id)
                snapEvaluatedStrokeIDs.insert(copy.id)
            }
        }
        isApplyingSelectionUpdate = true
        canvasView.drawing = PKDrawing(strokes: strokes)
        isApplyingSelectionUpdate = false
        return newIDs
    }

    private func duplicateTextObjects(of group: SelectionGroup) -> Set<UUID> {
        let offset = Self.duplicateOffset
        var newIDs: Set<UUID> = []
        for id in group.textObjectIDs {
            guard let object = textStore.textObjects.first(where: { $0.id == id }) else { continue }
            let copy = RecognizedTextObject(
                text: object.text,
                style: object.style,
                styleRuns: object.styleRuns,
                boundingBox: object.boundingBox.offsetBy(dx: offset.x, dy: offset.y),
                sourceStrokeIDs: []
            )
            textStore.add(copy)
            addTextOverlay(for: copy)
            newIDs.insert(copy.id)
        }
        return newIDs
    }

    private func duplicateImages(of group: SelectionGroup) -> Set<UUID> {
        let offset = Self.duplicateOffset
        var newIDs: Set<UUID> = []
        for id in group.imageIDs {
            guard let object = imageStore.imageObjects.first(where: { $0.id == id }) else { continue }
            let copy = ImageObject(
                imageData: object.imageData,
                frame: object.frame.offsetBy(dx: offset.x, dy: offset.y)
            )
            imageStore.add(copy)
            addImageOverlay(for: copy)
            newIDs.insert(copy.id)
        }
        return newIDs
    }

    func deleteGroup() {
        guard let group = selectionGroup, let canvasView = canvasViewRef else { return }

        if !group.strokeIDs.isEmpty {
            isApplyingSelectionUpdate = true
            canvasView.drawing = PKDrawing(
                strokes: canvasView.drawing.strokes.filter { !group.strokeIDs.contains($0.id) }
            )
            isApplyingSelectionUpdate = false
            snappedStrokeIDs.subtract(group.strokeIDs)
            snapEvaluatedStrokeIDs.subtract(group.strokeIDs)
        }
        for id in group.textObjectIDs { deleteTextObject(id: id) }
        for id in group.imageIDs {
            imageViewsByID[id]?.removeFromSuperview()
            imageViewsByID.removeValue(forKey: id)
            imageStore.remove(id: id)
        }
        clearGroupSelection()
    }

    // MARK: Geometry helpers

    private func textFrame(for id: UUID) -> CGRect? {
        textViewsByID[id]?.frame
    }

    private func groupRects(strokeIDs: Set<UUID>, textIDs: Set<UUID>, imageIDs: Set<UUID>) -> [CGRect] {
        var rects: [CGRect] = []
        if let canvasView = canvasViewRef {
            for stroke in canvasView.drawing.strokes where strokeIDs.contains(stroke.id) {
                rects.append(canvasView.convert(stroke.renderBounds, to: pageContainer))
            }
        }
        for id in textIDs { if let frame = textFrame(for: id) { rects.append(frame) } }
        for object in imageStore.imageObjects where imageIDs.contains(object.id) { rects.append(object.frame) }
        return rects
    }

    /// Samples evenly spaced points along the stroke's rendered curve via
    /// `interpolatedPoints(by:)`. Iterating `path` directly yields the raw
    /// B-spline control points, which sit off the visible line once a
    /// stroke has round-tripped through `canvasView.drawing`.
    private func strokeSamplePoints(_ stroke: PKStroke) -> [CGPoint] {
        let transform = stroke.transform
        var points = stroke.path
            .interpolatedPoints(by: .distance(Self.lassoSampleSpacing))
            .map { $0.location.applying(transform) }
        if points.count < 2 {
            points = stroke.path.map { $0.location.applying(transform) }
        }
        if points.isEmpty {
            points = [CGPoint(x: stroke.renderBounds.midX, y: stroke.renderBounds.midY)]
        }
        return points
    }

    private func captureGroupBaseline(_ group: SelectionGroup, in canvasView: PKCanvasView?) -> GroupDragBaseline {
        var textFrames: [UUID: CGRect] = [:]
        for id in group.textObjectIDs { textFrames[id] = textViewsByID[id]?.frame ?? .zero }
        var imageFrames: [UUID: CGRect] = [:]
        for id in group.imageIDs { imageFrames[id] = imageViewsByID[id]?.frame ?? .zero }
        return GroupDragBaseline(
            strokes: canvasView?.drawing.strokes ?? [],
            movedStrokeIDs: group.strokeIDs,
            textFrames: textFrames,
            imageFrames: imageFrames,
            boundingBox: group.boundingBox
        )
    }
}
