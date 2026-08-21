import Testing
import Foundation
import CoreGraphics
@testable import Wrytic

struct TextPositioningServiceTests {
    private func makeStroke(boundingBox: CGRect) -> CapturedStroke {
        CapturedStroke(id: UUID(), tool: .pen, points: [], boundingBox: boundingBox, createdAt: .now)
    }

    private func makeGroup(boundingBox: CGRect) -> StrokeGroup {
        StrokeGroup(strokes: [makeStroke(boundingBox: boundingBox)])
    }

    @Test func styleSizeAlwaysMatchesBaseStyleRegardlessOfStrokeHeight() {
        let service = HandwritingTextPositioningService()
        let small = makeGroup(boundingBox: CGRect(x: 0, y: 0, width: 80, height: 6))
        let large = makeGroup(boundingBox: CGRect(x: 0, y: 0, width: 80, height: 300))

        let smallPlacement = service.position(for: small, baseStyle: TextStyle.default)
        let largePlacement = service.position(for: large, baseStyle: TextStyle.default)

        #expect(smallPlacement.style == TextStyle.default)
        #expect(largePlacement.style == TextStyle.default)
    }

    @Test func horizontalOriginIsPreservedFromSourceStrokes() {
        let service = HandwritingTextPositioningService()
        let group = makeGroup(boundingBox: CGRect(x: 37, y: 0, width: 80, height: 20))

        let placement = service.position(for: group, baseStyle: TextStyle.default)

        #expect(placement.boundingBox.minX == 37)
    }

    @Test func verticalCenterIsPreservedFromSourceStrokes() {
        let service = HandwritingTextPositioningService()
        let bbox = CGRect(x: 0, y: 200, width: 80, height: 50)
        let group = makeGroup(boundingBox: bbox)

        let placement = service.position(for: group, baseStyle: TextStyle.default)

        #expect(abs(placement.boundingBox.midY - bbox.midY) < 0.001)
    }

    @Test func heightIsDerivedFromBaseStyleSize() {
        let service = HandwritingTextPositioningService()
        let group = makeGroup(boundingBox: CGRect(x: 0, y: 0, width: 80, height: 200))

        let placement = service.position(for: group, baseStyle: TextStyle.default)

        #expect(placement.boundingBox.height == ceil(TextStyle.default.size * service.labelHeightMultiplier))
    }

    @Test func zeroHeightBoundingBoxFallsBackToBaseStyleUnchanged() {
        let service = HandwritingTextPositioningService()
        let group = makeGroup(boundingBox: CGRect(x: 5, y: 5, width: 80, height: 0))

        let placement = service.position(for: group, baseStyle: TextStyle.default)

        #expect(placement.style == TextStyle.default)
        #expect(placement.boundingBox == group.boundingBox)
    }
}
