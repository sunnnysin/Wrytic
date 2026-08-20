import Testing
import Foundation
import PencilKit
@testable import Wrytic

struct StrokeCaptureServiceTests {
    private func makePoint(x: CGFloat, y: CGFloat) -> PKStrokePoint {
        PKStrokePoint(
            location: CGPoint(x: x, y: y),
            timeOffset: 0,
            size: CGSize(width: 2, height: 2),
            opacity: 1,
            force: 1,
            azimuth: 0,
            altitude: 0
        )
    }

    private func makeStroke(
        origin: CGPoint,
        width: CGFloat = 40,
        height: CGFloat = 10,
        inkType: PKInkingTool.InkType = .pen,
        creationDate: Date = .now
    ) -> PKStroke {
        let points = [
            makePoint(x: origin.x, y: origin.y),
            makePoint(x: origin.x + width, y: origin.y + height)
        ]
        let path = PKStrokePath(controlPoints: points, creationDate: creationDate)
        let ink = PKInk(inkType, color: .black)
        return PKStroke(ink: ink, path: path)
    }

    private let service = PencilKitStrokeCaptureService()

    @Test func captureDerivesGeometryAndTimestampFromStroke() {
        let creationDate = Date(timeIntervalSince1970: 100)
        let stroke = makeStroke(origin: CGPoint(x: 10, y: 20), creationDate: creationDate)
        let drawing = PKDrawing(strokes: [stroke])

        let captured = service.capture(from: drawing, shapeSnappedStrokeIDs: [])

        #expect(captured.count == 1)
        #expect(captured[0].id == stroke.id)
        #expect(captured[0].tool == .pen)
        #expect(captured[0].points.count == 2)
        #expect(captured[0].boundingBox == stroke.renderBounds)
        #expect(captured[0].createdAt == creationDate)
    }

    @Test func captureTagsMarkerInkAsHighlighter() {
        let stroke = makeStroke(origin: .zero, inkType: .marker)
        let drawing = PKDrawing(strokes: [stroke])

        let captured = service.capture(from: drawing, shapeSnappedStrokeIDs: [])

        #expect(captured[0].tool == .highlighter)
    }

    @Test func captureTagsShapeSnappedStrokesAsShapeRegardlessOfInk() {
        let stroke = makeStroke(origin: .zero, inkType: .pen)
        let drawing = PKDrawing(strokes: [stroke])

        let captured = service.capture(from: drawing, shapeSnappedStrokeIDs: [stroke.id])

        #expect(captured[0].tool == .shape)
    }

    @Test func groupJoinsVerticallyOverlappingStrokesIntoOneLine() {
        let left = makeStroke(origin: CGPoint(x: 0, y: 0))
        let right = makeStroke(origin: CGPoint(x: 60, y: 2))
        let drawing = PKDrawing(strokes: [left, right])
        let captured = service.capture(from: drawing, shapeSnappedStrokeIDs: [])

        let groups = service.group(captured)

        #expect(groups.count == 1)
        #expect(groups[0].strokes.count == 2)
        #expect(groups[0].strokes.map(\.id) == [left.id, right.id])
    }

    @Test func groupSeparatesStrokesOnDistinctLines() {
        let firstLine = makeStroke(origin: CGPoint(x: 0, y: 0))
        let secondLine = makeStroke(origin: CGPoint(x: 0, y: 200))
        let drawing = PKDrawing(strokes: [firstLine, secondLine])
        let captured = service.capture(from: drawing, shapeSnappedStrokeIDs: [])

        let groups = service.group(captured)

        #expect(groups.count == 2)
    }

    @Test func groupBoundingBoxUnionsItsStrokes() {
        let first = CapturedStroke(
            id: UUID(),
            tool: .pen,
            points: [],
            boundingBox: CGRect(x: 0, y: 0, width: 10, height: 10),
            createdAt: .now
        )
        let second = CapturedStroke(
            id: UUID(),
            tool: .pen,
            points: [],
            boundingBox: CGRect(x: 20, y: 5, width: 10, height: 10),
            createdAt: .now
        )
        let group = StrokeGroup(strokes: [first, second])

        #expect(group.boundingBox == CGRect(x: 0, y: 0, width: 30, height: 15))
    }
}
