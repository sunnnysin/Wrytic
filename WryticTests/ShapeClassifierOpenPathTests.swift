import Testing
import CoreGraphics
@testable import Wrytic

struct ShapeClassifierOpenPathTests {
    @Test func curvedShaftWithArrowheadClassifiesAsCurvedArrow() {
        let tail = CGPoint(x: 0, y: 0)
        let head = CGPoint(x: 200, y: 0)
        let control = CGPoint(x: 100, y: -70)
        var points = ShapePathBuilder.quadraticBezierPoints(from: tail, control: control, to: head, samples: 30)
        points += arrowheadFlare(head: head, shaftDirection: CGPoint(x: -1, y: 0), headAngle: 30, length: 24)
        #expect(ShapeClassifier.classify(points: points) == .curvedArrow)
    }

    @Test func curvedArrowFitPlacesTailAndHeadAtEnds() {
        let tail = CGPoint(x: 0, y: 0)
        let head = CGPoint(x: 200, y: 0)
        let control = CGPoint(x: 100, y: -70)
        var points = ShapePathBuilder.quadraticBezierPoints(from: tail, control: control, to: head, samples: 30)
        points += arrowheadFlare(head: head, shaftDirection: CGPoint(x: -1, y: 0), headAngle: 30, length: 24)
        guard case .curvedArrow(let fitTail, let fitHead, _) = ShapeClassifier.fit(points: points) else {
            Issue.record("Expected a curved arrow fit")
            return
        }
        #expect(ShapeClassifier.distance(fitTail, tail) < ShapeClassifier.distance(fitHead, tail))
    }

    @Test func rightAngleZigzagClassifiesAsOrthogonalPolyline() {
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 80),
            CGPoint(x: 180, y: 80)
        ]
        let points = samplePerimeter(corners: corners)
        #expect(ShapeClassifier.classify(points: points) == .orthogonalPolyline)
    }

    @Test func orthogonalPolylineRejectsADiagonalSegment() {
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 160, y: 80),
            CGPoint(x: 240, y: 80)
        ]
        let points = samplePerimeter(corners: corners)
        #expect(ShapeClassifier.classify(points: points) != .orthogonalPolyline)
    }

    private func arrowheadFlare(
        head: CGPoint,
        shaftDirection: CGPoint,
        headAngle: CGFloat,
        length: CGFloat
    ) -> [CGPoint] {
        let angle = headAngle * .pi / 180
        func rotate(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
            CGPoint(x: point.x * cos(angle) - point.y * sin(angle), y: point.x * sin(angle) + point.y * cos(angle))
        }
        let flank1Direction = rotate(shaftDirection, by: angle)
        let flank2Direction = rotate(shaftDirection, by: -angle)
        let flank1 = CGPoint(x: head.x + flank1Direction.x * length, y: head.y + flank1Direction.y * length)
        let flank2 = CGPoint(x: head.x + flank2Direction.x * length, y: head.y + flank2Direction.y * length)
        return samplePerimeter(corners: [head, flank1], samplesPerSegment: 8)
            + samplePerimeter(corners: [flank1, head], samplesPerSegment: 8)
            + samplePerimeter(corners: [head, flank2], samplesPerSegment: 8)
    }

    private func samplePerimeter(corners: [CGPoint], samplesPerSegment: Int = 15) -> [CGPoint] {
        var result: [CGPoint] = []
        for index in 0..<(corners.count - 1) {
            let start = corners[index]
            let end = corners[index + 1]
            for step in 0..<samplesPerSegment {
                let fraction = CGFloat(step) / CGFloat(samplesPerSegment)
                result.append(CGPoint(
                    x: start.x + (end.x - start.x) * fraction,
                    y: start.y + (end.y - start.y) * fraction
                ))
            }
        }
        return result
    }
}
