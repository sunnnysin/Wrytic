import Testing
import UIKit
import PencilKit
@testable import Wrytic

@MainActor
struct PencilCanvasViewLassoTests {
    /// `pageContainer` is held `weak` by the coordinator, so the rig keeps
    /// a strong reference for the test's lifetime — dropping it makes
    /// `insertImage` and the overlay wiring silently no-op.
    private struct Rig {
        let coordinator: PencilCanvasView.Coordinator
        let pageContainer: UIView
        let canvasView: PKCanvasView
    }

    private func makeRig() -> Rig {
        let coordinator = PencilCanvasView.Coordinator(
            fontSettings: FontSettingsStore(),
            recognitionSettings: RecognitionSettingsStore(),
            textStore: RecognizedTextStore(),
            imageStore: ImageObjectStore(),
            lassoActions: LassoActionsModel()
        )
        let pageContainer = UIView(frame: CGRect(origin: .zero, size: PencilCanvasConfiguration.pageSize))
        let canvasView = PKCanvasView(frame: pageContainer.bounds)
        pageContainer.addSubview(canvasView)
        coordinator.pageContainer = pageContainer
        coordinator.canvasViewRef = canvasView
        return Rig(coordinator: coordinator, pageContainer: pageContainer, canvasView: canvasView)
    }

    private func makeImage(width: CGFloat = 40, height: CGFloat = 20) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func stroke(from start: CGPoint, to end: CGPoint) -> PKStroke {
        let points = (0...20).map { step -> PKStrokePoint in
            let fraction = CGFloat(step) / 20
            return PKStrokePoint(
                location: CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction),
                timeOffset: TimeInterval(step) * 0.01, size: CGSize(width: 3, height: 3),
                opacity: 1, force: 1, azimuth: 0, altitude: 0
            )
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: .now))
    }

    private func shapeStroke(ellipseIn rect: CGRect) -> PKStroke {
        let path = ShapePathBuilder.strokePath(
            for: .ellipse(rect), creationDate: .now, pointSize: CGSize(width: 3, height: 3)
        )
        return PKStroke(ink: PKInk(.pen, color: .black), path: path)
    }

    private func text(at box: CGRect) -> RecognizedTextObject {
        RecognizedTextObject(text: "note", style: .default, boundingBox: box, sourceStrokeIDs: [])
    }

    private let wholePageLoop = [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 1590, y: 0),
        CGPoint(x: 1590, y: 2190),
        CGPoint(x: 0, y: 2190)
    ]

    @Test func lassoAroundMixedContentSelectsEveryEnclosedItem() throws {
        let rig = makeRig()
        let ink = stroke(from: CGPoint(x: 300, y: 300), to: CGPoint(x: 360, y: 320))
        rig.canvasView.drawing = PKDrawing(strokes: [ink])
        let textObject = text(at: CGRect(x: 500, y: 500, width: 120, height: 40))
        rig.coordinator.textStore.add(textObject)
        rig.coordinator.addTextOverlay(for: textObject)
        rig.coordinator.insertImage(makeImage())
        let imageID = try #require(rig.coordinator.imageStore.imageObjects.first).id
        rig.coordinator.deselectImage()

        rig.coordinator.setLassoMode(true)
        rig.coordinator.completeLasso(wholePageLoop)

        let group = try #require(rig.coordinator.selectionGroup)
        #expect(group.strokeIDs == [ink.id])
        #expect(group.textObjectIDs == [textObject.id])
        #expect(group.imageIDs == [imageID])
        #expect(rig.coordinator.lassoOverlay.map { rig.pageContainer.subviews.contains($0) } == true)
    }

    @Test func lassoSelectsASnappedShapeStrokeItEnclosesButNotOneOutside() throws {
        let rig = makeRig()
        let inside = shapeStroke(ellipseIn: CGRect(x: 300, y: 300, width: 200, height: 150))
        let outside = shapeStroke(ellipseIn: CGRect(x: 900, y: 900, width: 200, height: 150))
        rig.canvasView.drawing = PKDrawing(strokes: [inside, outside])

        rig.coordinator.setLassoMode(true)
        rig.coordinator.completeLasso([
            CGPoint(x: 260, y: 260), CGPoint(x: 560, y: 260),
            CGPoint(x: 560, y: 520), CGPoint(x: 260, y: 520)
        ])

        #expect(rig.coordinator.selectionGroup?.strokeIDs == [inside.id])
    }

    @Test func lassoDoesNotSelectAStrokeWhoseInkFallsOutsideEvenIfItsBoundingBoxOverlaps() throws {
        let rig = makeRig()
        let diagonal = stroke(from: CGPoint(x: 200, y: 200), to: CGPoint(x: 1200, y: 1000))
        rig.canvasView.drawing = PKDrawing(strokes: [diagonal])

        rig.coordinator.setLassoMode(true)
        rig.coordinator.completeLasso([
            CGPoint(x: 1000, y: 220), CGPoint(x: 1180, y: 220),
            CGPoint(x: 1180, y: 400), CGPoint(x: 1000, y: 400)
        ])

        #expect(rig.coordinator.selectionGroup == nil)
    }

    @Test func lassoThatEnclosesNothingLeavesNoSelection() {
        let rig = makeRig()
        rig.coordinator.insertImage(makeImage())
        rig.coordinator.deselectImage()
        rig.coordinator.setLassoMode(true)

        rig.coordinator.completeLasso([
            CGPoint(x: 5, y: 5), CGPoint(x: 20, y: 5), CGPoint(x: 20, y: 20), CGPoint(x: 5, y: 20)
        ])

        #expect(rig.coordinator.selectionGroup == nil)
    }

    @Test func movingTheGroupTranslatesEveryMemberAndCommitsOnRelease() throws {
        let rig = makeRig()
        let ink = stroke(from: CGPoint(x: 400, y: 400), to: CGPoint(x: 440, y: 410))
        rig.canvasView.drawing = PKDrawing(strokes: [ink])
        rig.coordinator.insertImage(makeImage())
        let image = try #require(rig.coordinator.imageStore.imageObjects.first)
        rig.coordinator.deselectImage()

        rig.coordinator.setLassoMode(true)
        rig.coordinator.completeLasso(wholePageLoop)
        rig.coordinator.lassoOverlay?.onMove?(CGPoint(x: 30, y: -12))
        rig.coordinator.lassoOverlay?.onGestureEnded?()

        let movedImage = rig.coordinator.imageStore.imageObjects.first { $0.id == image.id }
        #expect(movedImage?.frame.origin == CGPoint(x: image.frame.minX + 30, y: image.frame.minY - 12))
        let transform = rig.canvasView.drawing.strokes.first { $0.id == ink.id }?.transform
        #expect(transform.map { abs($0.tx - 30) < 0.001 && abs($0.ty + 12) < 0.001 } == true)
    }

    @Test func duplicatingTheGroupAddsAnOffsetCopyOfEveryMember() throws {
        let rig = makeRig()
        rig.canvasView.drawing = PKDrawing(strokes: [
            stroke(from: CGPoint(x: 500, y: 500), to: CGPoint(x: 540, y: 520))
        ])
        let textObject = text(at: CGRect(x: 600, y: 600, width: 100, height: 40))
        rig.coordinator.textStore.add(textObject)
        rig.coordinator.addTextOverlay(for: textObject)
        rig.coordinator.insertImage(makeImage())
        rig.coordinator.deselectImage()

        rig.coordinator.setLassoMode(true)
        rig.coordinator.completeLasso(wholePageLoop)
        rig.coordinator.duplicateGroup()

        #expect(rig.coordinator.imageStore.imageObjects.count == 2)
        #expect(rig.coordinator.textStore.textObjects.count == 2)
        #expect(rig.canvasView.drawing.strokes.count == 2)
        #expect(try #require(rig.coordinator.selectionGroup).count == 3)
    }

    @Test func deletingTheGroupRemovesEveryMember() throws {
        let rig = makeRig()
        rig.canvasView.drawing = PKDrawing(strokes: [
            stroke(from: CGPoint(x: 600, y: 600), to: CGPoint(x: 640, y: 620))
        ])
        let textObject = text(at: CGRect(x: 700, y: 700, width: 100, height: 40))
        rig.coordinator.textStore.add(textObject)
        rig.coordinator.addTextOverlay(for: textObject)
        rig.coordinator.insertImage(makeImage())
        rig.coordinator.deselectImage()

        rig.coordinator.setLassoMode(true)
        rig.coordinator.completeLasso(wholePageLoop)
        #expect(try #require(rig.coordinator.selectionGroup).count == 3)
        rig.coordinator.deleteGroup()

        #expect(rig.coordinator.imageStore.imageObjects.isEmpty)
        #expect(rig.coordinator.textStore.textObjects.isEmpty)
        #expect(rig.canvasView.drawing.strokes.isEmpty)
        #expect(rig.coordinator.selectionGroup == nil)
    }

    @Test func leavingLassoModeTearsDownTheOverlayAndSelection() {
        let rig = makeRig()
        rig.coordinator.insertImage(makeImage())
        rig.coordinator.deselectImage()
        rig.coordinator.setLassoMode(true)
        rig.coordinator.completeLasso(wholePageLoop)
        let overlay = rig.coordinator.lassoOverlay

        rig.coordinator.setLassoMode(false)

        #expect(rig.coordinator.lassoOverlay == nil)
        #expect(rig.coordinator.selectionGroup == nil)
        if let overlay { #expect(!rig.pageContainer.subviews.contains(overlay)) }
    }

    @Test func aLoneImageSelectionExposesResizeAndScalesFromTheHandle() throws {
        let rig = makeRig()
        rig.coordinator.insertImage(makeImage(width: 100, height: 50))
        let image = try #require(rig.coordinator.imageStore.imageObjects.first)
        rig.coordinator.deselectImage()

        rig.coordinator.setLassoMode(true)
        rig.coordinator.completeLasso(wholePageLoop)
        #expect(rig.coordinator.selectionGroup?.resizableImageID == image.id)

        rig.coordinator.lassoOverlay?.onResize?(CGPoint(x: image.frame.minX + 400, y: image.frame.minY + 999))
        rig.coordinator.lassoOverlay?.onGestureEnded?()

        let resized = rig.coordinator.imageStore.imageObjects.first { $0.id == image.id }
        #expect(resized?.frame.width == 400)
        #expect(resized?.frame.height == 200)
    }
}
