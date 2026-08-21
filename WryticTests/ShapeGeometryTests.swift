import Testing
import Foundation
@testable import Wrytic

struct ShapeGeometryTests {
    @Test func distanceToSegmentIsZeroOnTheLine() {
        let distance = ShapeGeometry.distanceToPolyline(
            CGPoint(x: 50, y: 50),
            [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)],
            closed: false
        )

        #expect(distance < 0.001)
    }

    @Test func distanceToSegmentMeasuresPerpendicularOffset() {
        let distance = ShapeGeometry.distanceToPolyline(
            CGPoint(x: 0, y: 10),
            [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)],
            closed: false
        )

        #expect(distance == 10)
    }

    @Test func distanceToSegmentClampsPastEndpoints() {
        let distance = ShapeGeometry.distanceToPolyline(
            CGPoint(x: -30, y: 0),
            [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)],
            closed: false
        )

        #expect(distance == 30)
    }

    /// The closing edge runs from the last point back to the first — here
    /// that's (0,100) back to (0,0). A point sitting exactly on it is
    /// distance 0 when closed, but only reachable via the other, farther
    /// edges when open, since that wrap-around edge doesn't exist.
    @Test func distanceIgnoresTheClosingSegmentWhenOpen() {
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100), CGPoint(x: 0, y: 100)]
        let pointOnClosingEdge = CGPoint(x: 0, y: 50)

        let openDistance = ShapeGeometry.distanceToPolyline(pointOnClosingEdge, square, closed: false)
        let closedDistance = ShapeGeometry.distanceToPolyline(pointOnClosingEdge, square, closed: true)

        #expect(closedDistance == 0)
        #expect(openDistance > closedDistance)
    }

    @Test func pointInPolygonDetectsInterior() {
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100), CGPoint(x: 0, y: 100)]

        #expect(ShapeGeometry.pointInPolygon(CGPoint(x: 50, y: 50), square))
        #expect(!ShapeGeometry.pointInPolygon(CGPoint(x: 150, y: 50), square))
    }

    @Test func pointInPolygonNeedsAtLeastThreePoints() {
        let line = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)]

        #expect(!ShapeGeometry.pointInPolygon(CGPoint(x: 50, y: 50), line))
    }
}
