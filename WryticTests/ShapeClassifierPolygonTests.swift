import Testing
import CoreGraphics
@testable import Wrytic

struct ShapeClassifierPolygonTests {
    @Test func roughTriangleClassifiesAsTriangle() {
        let corners = [CGPoint(x: 50, y: 0), CGPoint(x: 100, y: 90), CGPoint(x: 0, y: 90), CGPoint(x: 50, y: 0)]
        let points = samplePerimeter(corners: corners)
        #expect(ShapeClassifier.classify(points: points) == .triangle)
    }

    @Test func triangleFitReturnsThreeDistinctVertices() {
        let corners = [CGPoint(x: 50, y: 0), CGPoint(x: 100, y: 90), CGPoint(x: 0, y: 90), CGPoint(x: 50, y: 0)]
        let points = samplePerimeter(corners: corners)
        guard case .triangle(let first, let second, let third) = ShapeClassifier.fit(points: points) else {
            Issue.record("Expected a triangle fit")
            return
        }
        #expect(first != second)
        #expect(second != third)
        #expect(first != third)
    }

    @Test func regularPentagonClassifiesAsPentagon() {
        let vertices = ShapePathBuilder.regularPolygonVertices(
            center: CGPoint(x: 60, y: 60),
            radius: 50,
            rotation: 0,
            sides: 5
        )
        let points = samplePerimeter(corners: vertices + [vertices[0]])
        #expect(ShapeClassifier.classify(points: points) == .pentagon)
    }

    @Test func pentagonFitProducesFiveRegularSides() {
        let vertices = ShapePathBuilder.regularPolygonVertices(
            center: CGPoint(x: 60, y: 60),
            radius: 50,
            rotation: 0,
            sides: 5
        )
        let points = samplePerimeter(corners: vertices + [vertices[0]])
        guard case .regularPolygon(let center, let radius, _, let sides) = ShapeClassifier.fit(points: points) else {
            Issue.record("Expected a regular polygon fit")
            return
        }
        #expect(sides == 5)
        #expect(abs(center.x - 60) < 5)
        #expect(abs(center.y - 60) < 5)
        #expect(abs(radius - 50) < 8)
    }

    @Test func regularHexagonClassifiesAsHexagon() {
        let vertices = ShapePathBuilder.regularPolygonVertices(
            center: CGPoint(x: 60, y: 60),
            radius: 50,
            rotation: 0,
            sides: 6
        )
        let points = samplePerimeter(corners: vertices + [vertices[0]])
        #expect(ShapeClassifier.classify(points: points) == .hexagon)
    }

    /// A rectangle with a slight overshoot 5th corner must still classify
    /// as a rectangle, not a pentagon — this is the exact ambiguity the
    /// regularity check (equal side lengths/angles) exists to resolve.
    @Test func rectangleWithOvershootCornerIsNotMisreadAsPentagon() {
        let rect = CGRect(x: 0, y: 0, width: 120, height: 80)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX + 6, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.minY)
        ]
        let points = samplePerimeter(corners: corners)
        #expect(ShapeClassifier.classify(points: points) == .rectangle)
    }

    @Test func fivePointStarClassifiesAsStar() {
        let vertices = ShapePathBuilder.starVertices(
            center: CGPoint(x: 60, y: 60),
            outerRadius: 50,
            innerRadius: 20,
            rotation: -.pi / 2
        )
        let points = samplePerimeter(corners: vertices + [vertices[0]])
        #expect(ShapeClassifier.classify(points: points) == .star)
    }

    @Test func starFitPreservesOuterInnerRadiusGap() {
        let vertices = ShapePathBuilder.starVertices(
            center: CGPoint(x: 60, y: 60),
            outerRadius: 50,
            innerRadius: 20,
            rotation: -.pi / 2
        )
        let points = samplePerimeter(corners: vertices + [vertices[0]])
        guard case .star(_, let outerRadius, let innerRadius, _) = ShapeClassifier.fit(points: points) else {
            Issue.record("Expected a star fit")
            return
        }
        #expect(outerRadius > innerRadius)
        #expect(abs(outerRadius - 50) < 10)
        #expect(abs(innerRadius - 20) < 10)
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
