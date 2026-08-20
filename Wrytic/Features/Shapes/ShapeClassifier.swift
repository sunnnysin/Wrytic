import CoreGraphics

enum ShapeClassifier {
    static let closureThresholdRatio: CGFloat = 0.15
    static let lineDeviationThresholdRatio: CGFloat = 0.08
    static let cornerSimplificationRatio: CGFloat = 0.06
    static let rectangleCornerRange = 4...5
    /// perimeter^2 / (4*pi*area): 1.0 for a perfect circle, ~1.27 for a
    /// square. Set to comfortably cover realistically eccentric hand-drawn
    /// ellipses (up to roughly a 2.5:1 aspect ratio) without crossing into
    /// square territory. Extremely flat ellipses (beyond ~3:1) converge
    /// with rectangle-like corner/compactness signatures and aren't
    /// reliably separable from geometry alone — the same ambiguity a
    /// person has glancing at a very flat oval vs. a heavily
    /// rounded-corner rectangle.
    static let circleCompactnessThreshold: CGFloat = 1.5
    static let minimumPointsRequired = 4
    /// Bounding-box diagonal below this is treated as handwriting-scale
    /// (e.g. a lowercase "o" loop), not an intentional shape — this uses
    /// the diagonal rather than width/height independently so a long,
    /// naturally thin straight line isn't rejected for having near-zero
    /// height.
    static let minimumBoundingBoxDiagonal: CGFloat = 44

    static func classify(points: [CGPoint]) -> ShapeType? {
        guard points.count >= minimumPointsRequired, let first = points.first, let last = points.last else {
            return nil
        }
        let bbox = boundingBox(of: points)
        let diagonal = (bbox.width * bbox.width + bbox.height * bbox.height).squareRoot()
        guard diagonal >= minimumBoundingBoxDiagonal else { return nil }

        let closingGap = distance(first, last)
        let isClosed = closingGap <= diagonal * closureThresholdRatio

        if !isClosed {
            if maxDeviationFromLine(points: points) <= diagonal * lineDeviationThresholdRatio {
                return .line
            }
            return nil
        }

        var closedLoop = points
        if closingGap > 0 { closedLoop.append(first) }
        let simplified = douglasPeucker(points: closedLoop, epsilon: diagonal * cornerSimplificationRatio)
        let cornerCount = simplified.count - 1

        let area = enclosedArea(points: simplified)
        guard area > 0 else { return nil }

        if rectangleCornerRange.contains(cornerCount) {
            return .rectangle
        }
        let perimeter = perimeterLength(points: simplified)
        let compactness = (perimeter * perimeter) / (4 * .pi * area)
        if compactness <= circleCompactnessThreshold {
            return .ellipse
        }
        return nil
    }

    static func fit(points: [CGPoint]) -> ShapeFit? {
        guard let type = classify(points: points), let first = points.first, let last = points.last else {
            return nil
        }
        switch type {
        case .line:
            return .line(start: first, end: last)
        case .rectangle:
            return .rectangle(boundingBox(of: points))
        case .ellipse:
            return .ellipse(boundingBox(of: points))
        }
    }

    static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func distance(_ pointA: CGPoint, _ pointB: CGPoint) -> CGFloat {
        ((pointA.x - pointB.x) * (pointA.x - pointB.x) + (pointA.y - pointB.y) * (pointA.y - pointB.y)).squareRoot()
    }

    static func maxDeviationFromLine(points: [CGPoint]) -> CGFloat {
        guard let start = points.first, let end = points.last, start != end else { return .infinity }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        var maxDeviation: CGFloat = 0
        for point in points {
            let projectionFraction = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
            let projected = CGPoint(
                x: start.x + projectionFraction * dx,
                y: start.y + projectionFraction * dy
            )
            maxDeviation = max(maxDeviation, distance(point, projected))
        }
        return maxDeviation
    }

    static func enclosedArea(points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var sum: CGFloat = 0
        for index in 0..<points.count {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            sum += (current.x * next.y) - (next.x * current.y)
        }
        return abs(sum) / 2
    }

    static func perimeterLength(points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var total: CGFloat = 0
        for index in 0..<(points.count - 1) {
            total += distance(points[index], points[index + 1])
        }
        return total
    }

    /// Ramer-Douglas-Peucker polyline simplification. Reduces a stroke to
    /// its dominant vertices — a shape with a handful of straight edges
    /// (a rectangle) collapses to ~4 points under a modest tolerance, while
    /// a curve (a circle/ellipse) needs many more points to stay within
    /// that same tolerance. This is what actually separates the two
    /// shapes structurally, unlike comparing enclosed area to bounding-box
    /// area, which a sloppily-drawn circle and a sloppily-drawn rectangle
    /// can both land close to either side of.
    static func douglasPeucker(points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count > 2, let start = points.first, let end = points.last else { return points }
        var maxDistance: CGFloat = 0
        var splitIndex = 0
        for index in 1..<(points.count - 1) {
            let pointDistance = perpendicularDistance(points[index], lineStart: start, lineEnd: end)
            if pointDistance > maxDistance {
                maxDistance = pointDistance
                splitIndex = index
            }
        }
        guard maxDistance > epsilon else { return [start, end] }
        let left = douglasPeucker(points: Array(points[0...splitIndex]), epsilon: epsilon)
        let right = douglasPeucker(points: Array(points[splitIndex...(points.count - 1)]), epsilon: epsilon)
        return Array(left.dropLast()) + right
    }

    static func perpendicularDistance(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        guard lineStart != lineEnd else { return distance(point, lineStart) }
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy
        let projectionFraction = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared
        let projected = CGPoint(x: lineStart.x + projectionFraction * dx, y: lineStart.y + projectionFraction * dy)
        return distance(point, projected)
    }
}
