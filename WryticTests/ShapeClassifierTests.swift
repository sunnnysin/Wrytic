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

    @Test func fitProducesLineWithOriginalEndpoints() {
        let points = stride(from: 0, through: 100, by: 5).map { CGPoint(x: CGFloat($0), y: 40) }
        guard case let .line(start, end) = ShapeClassifier.fit(points: points) else {
            Issue.record("Expected a line fit")
            return
        }
        #expect(start == points.first)
        #expect(end == points.last)
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
