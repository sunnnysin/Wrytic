import Testing
import Foundation
import PencilKit
@testable import Wrytic

struct StrokeToolTests {
    private func makeStroke(inkType: PKInkingTool.InkType) -> PKStroke {
        let point = PKStrokePoint(
            location: .zero,
            timeOffset: 0,
            size: CGSize(width: 1, height: 1),
            opacity: 1,
            force: 1,
            azimuth: 0,
            altitude: 0
        )
        let path = PKStrokePath(controlPoints: [point], creationDate: .now)
        let ink = PKInk(inkType, color: .black)
        return PKStroke(ink: ink, path: path)
    }

    @Test func penInkMapsToPenTool() {
        let stroke = makeStroke(inkType: .pen)
        #expect(StrokeTool.from(stroke) == .pen)
    }

    @Test func markerInkMapsToHighlighterTool() {
        let stroke = makeStroke(inkType: .marker)
        #expect(StrokeTool.from(stroke) == .highlighter)
    }

    @Test func otherInkTypesFallBackToPen() {
        let stroke = makeStroke(inkType: .pencil)
        #expect(StrokeTool.from(stroke) == .pen)
    }

    @Test func shapeSnappedOverridesInkType() {
        let stroke = makeStroke(inkType: .pen)
        #expect(StrokeTool.from(stroke, isShapeSnapped: true) == .shape)
    }
}
