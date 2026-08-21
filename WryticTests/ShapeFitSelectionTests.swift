import Testing
import Foundation
@testable import Wrytic

struct ShapeFitSelectionTests {
    /// The bug this whole file guards against: a diagonal line's bounding
    /// box can cover most of the page, but a tap in the empty corner of
    /// that box (nowhere near the visible ink) must not count as "on the
    /// shape" — otherwise tap-to-deselect never fires there.
    @Test func diagonalLineRejectsATapInTheEmptyCornerOfItsBoundingBox() {
        let line = ShapeFit.line(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 1400, y: 2000))

        let emptyCorner = CGPoint(x: 1350, y: 150)

        #expect(!line.isNear(emptyCorner, tolerance: 16))
    }

    @Test func lineAcceptsATapOnTheStrokeItself() {
        let line = ShapeFit.line(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 200, y: 0))

        #expect(line.isNear(CGPoint(x: 100, y: 5), tolerance: 16))
    }

    @Test func arrowRejectsATapFarFromTheShaft() {
        let arrow = ShapeFit.arrow(tail: CGPoint(x: 0, y: 0), head: CGPoint(x: 1000, y: 800))

        #expect(!arrow.isNear(CGPoint(x: 900, y: 50), tolerance: 16))
    }

    @Test func rectangleAcceptsATapAnywhereInsideItsArea() {
        let rectangle = ShapeFit.rectangle(CGRect(x: 0, y: 0, width: 200, height: 200))

        #expect(rectangle.isNear(CGPoint(x: 100, y: 100), tolerance: 16))
    }

    @Test func ellipseRejectsATapInItsBoundingBoxCornerOutsideTheCurve() {
        let ellipse = ShapeFit.ellipse(CGRect(x: 0, y: 0, width: 400, height: 100))

        #expect(!ellipse.isNear(CGPoint(x: 5, y: 5), tolerance: 4))
    }

    @Test func ellipseAcceptsATapNearItsCenter() {
        let ellipse = ShapeFit.ellipse(CGRect(x: 0, y: 0, width: 400, height: 100))

        #expect(ellipse.isNear(CGPoint(x: 200, y: 50), tolerance: 4))
    }

    @Test func isClosedIsTrueOnlyForFilledShapes() {
        #expect(ShapeFit.rectangle(.zero).isClosed)
        #expect(ShapeFit.ellipse(.zero).isClosed)
        #expect(!ShapeFit.line(start: .zero, end: .zero).isClosed)
        #expect(!ShapeFit.arrow(tail: .zero, head: .zero).isClosed)
    }
}
