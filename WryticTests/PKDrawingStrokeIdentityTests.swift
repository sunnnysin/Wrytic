import Testing
import PencilKit
@testable import Wrytic

/// The lasso group-move rebuilds `canvasView.drawing` on every drag tick
/// and relies on `PKStroke.id` surviving that round-trip so the moved
/// strokes can still be found next tick. This pins that assumption.
struct PKDrawingStrokeIdentityTests {
    private func line() -> PKStroke {
        let points = (0...10).map { step in
            PKStrokePoint(
                location: CGPoint(x: step * 10, y: 0),
                timeOffset: TimeInterval(step) * 0.01, size: CGSize(width: 3, height: 3),
                opacity: 1, force: 1, azimuth: 0, altitude: 0
            )
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: .now))
    }

    @Test func strokeIDAndTransformSurviveDrawingReassignment() throws {
        let original = line()
        var drawing = PKDrawing(strokes: [original])
        let readBackID = try #require(drawing.strokes.first).id
        #expect(readBackID == original.id)

        var strokes = drawing.strokes
        strokes[0].transform = CGAffineTransform(translationX: 40, y: 7)
        drawing = PKDrawing(strokes: strokes)

        let moved = try #require(drawing.strokes.first)
        #expect(moved.id == original.id)
        #expect(moved.transform.tx == 40)
        #expect(moved.transform.ty == 7)
    }
}
