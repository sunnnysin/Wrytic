import CoreGraphics

enum ShapeClassifier {
    static let closureThresholdRatio: CGFloat = 0.15
    static let lineDeviationThresholdRatio: CGFloat = 0.08
    static let rectangleAreaRatioThreshold: CGFloat = 0.7
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

        guard bbox.width > 1, bbox.height > 1 else { return nil }
        let areaRatio = enclosedArea(points: points) / (bbox.width * bbox.height)
        if areaRatio >= rectangleAreaRatioThreshold {
            return .rectangle
        } else if areaRatio > 0 {
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
}
