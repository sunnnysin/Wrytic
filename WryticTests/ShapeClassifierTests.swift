import Testing
import CoreGraphics
@testable import Wrytic

struct ShapeClassifierTests {
    @Test func straightLineClassifiesAsLine() {
        let points = stride(from: 0, through: 100, by: 5).map { CGPoint(x: CGFloat($0), y: 40) }
        #expect(ShapeClassifier.classify(points: points) == .line)
    }

    @Test func roughRectangleClassifiesAsRectangle() {
        let rect = CGRect(x: 0, y: 0, width: 120, height: 80)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.minY)
        ]
        let points = samplePerimeter(corners: corners)
        #expect(ShapeClassifier.classify(points: points) == .rectangle)
    }

    @Test func roughCircleClassifiesAsEllipse() {
        let center = CGPoint(x: 50, y: 50)
        let radius: CGFloat = 40
        let points = (0..<60).map { step -> CGPoint in
            let angle = (CGFloat(step) / 60) * 2 * .pi
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        #expect(ShapeClassifier.classify(points: points) == .ellipse)
    }

    @Test func scribbleDoesNotMatchAnyShape() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 20), CGPoint(x: -10, y: 15),
            CGPoint(x: 20, y: -5), CGPoint(x: 5, y: 30), CGPoint(x: -15, y: 5)
        ]
        #expect(ShapeClassifier.classify(points: points) == nil)
    }

    @Test func tooFewPointsDoesNotClassify() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)]
        #expect(ShapeClassifier.classify(points: points) == nil)
    }

    @Test func perfectlyHorizontalLineIsNotRejectedForZeroHeight() {
        let points = stride(from: 0, through: 120, by: 6).map { CGPoint(x: CGFloat($0), y: 40) }
        #expect(ShapeClassifier.classify(points: points) == .line)
    }

    @Test func perfectlyVerticalLineIsNotRejectedForZeroWidth() {
        let points = stride(from: 0, through: 120, by: 6).map { CGPoint(x: 40, y: CGFloat($0)) }
        #expect(ShapeClassifier.classify(points: points) == .line)
    }

    @Test func flattenedHandDrawnEllipseWithHighFillRatioStillClassifiesAsEllipse() {
        let center = CGPoint(x: 50, y: 30)
        let radiusX: CGFloat = 60
        let radiusY: CGFloat = 25
        let points = (0..<80).map { step -> CGPoint in
            let angle = (CGFloat(step) / 80) * 2 * .pi
            return CGPoint(x: center.x + radiusX * cos(angle), y: center.y + radiusY * sin(angle))
        }
        #expect(ShapeClassifier.classify(points: points) == .ellipse)
    }

    @Test func roundedCornerRectangleWithLowFillRatioStillClassifiesAsRectangle() {
        let points = roundedRectanglePoints(rect: CGRect(x: 0, y: 0, width: 140, height: 90), cornerRadius: 20)
        #expect(ShapeClassifier.classify(points: points) == .rectangle)
    }

    @Test func smallHandwritingScaleLoopIsNotClassifiedAsAShape() {
        let center = CGPoint(x: 10, y: 10)
        let radius: CGFloat = 8
        let points = (0..<20).map { step -> CGPoint in
            let angle = (CGFloat(step) / 20) * 2 * .pi
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        #expect(ShapeClassifier.classify(points: points) == nil)
    }

    @Test func fitProducesLineWithOriginalEndpoints() {
        let points = stride(from: 0, through: 100, by: 5).map { CGPoint(x: CGFloat($0), y: 40) }
        guard case let .line(start, end) = ShapeClassifier.fit(points: points) else {
            Issue.record("Expected a line fit")
            return
        }
        #expect(start == points.first)
        #expect(end == points.last)
    }

    private func roundedRectanglePoints(rect: CGRect, cornerRadius: CGFloat) -> [CGPoint] {
        let arcs: [(center: CGPoint, startAngle: CGFloat)] = [
            (CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius), -.pi / 2),
            (CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius), 0),
            (CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius), .pi / 2),
            (CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius), .pi)
        ]
        var points: [CGPoint] = []
        for (index, arc) in arcs.enumerated() {
            for step in 0...8 {
                let angle = arc.startAngle + (CGFloat(step) / 8) * (.pi / 2)
                let x = arc.center.x + cornerRadius * cos(angle)
                let y = arc.center.y + cornerRadius * sin(angle)
                points.append(CGPoint(x: x, y: y))
            }
            let next = arcs[(index + 1) % arcs.count]
            let nextStart = CGPoint(
                x: next.center.x + cornerRadius * cos(next.startAngle),
                y: next.center.y + cornerRadius * sin(next.startAngle)
            )
            guard let last = points.last else { continue }
            for step in 1..<6 {
                let fraction = CGFloat(step) / 6
                points.append(CGPoint(
                    x: last.x + (nextStart.x - last.x) * fraction,
                    y: last.y + (nextStart.y - last.y) * fraction
                ))
            }
        }
        return points
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
