import CoreGraphics

enum ShapeClassifier {
    static let closureThresholdRatio: CGFloat = 0.15
    static let lineDeviationThresholdRatio: CGFloat = 0.08
    /// Deviation-from-line tolerance used only to decide whether a point
    /// near one end of an open stroke counts as part of an arrowhead
    /// "flare". Tighter than lineDeviationThresholdRatio so moderately
    /// small arrowheads still register instead of blending into normal
    /// hand wobble along the shaft.
    static let arrowFlareDeviationRatio: CGFloat = 0.05
    static let arrowMinimumFlaredPoints = 3
    static let arrowFlareDominanceRatio: CGFloat = 3
    /// How close (as a fraction of tail-to-head span) a point must be to
    /// an endpoint to count toward that endpoint's flare density — see
    /// `detectCurvedArrow`.
    static let flareProximityRatio: CGFloat = 0.22
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
    /// How much a regular polygon's (pentagon/hexagon) side lengths and
    /// interior angles may vary — as a coefficient of variation
    /// (stddev/mean) — and still count as "regular" rather than an
    /// irregular rectangle-with-an-overshoot-corner landing on the same
    /// corner count.
    static let regularPolygonToleranceRatio: CGFloat = 0.28
    /// A 5-point star traced continuously has 10 direction-changing
    /// vertices (5 outer tips + 5 inner notches).
    static let starVertexCount = 10
    /// Douglas-Peucker's single-split-per-recursion-level approach can
    /// spuriously keep an extra, nearly-colinear sample point when a
    /// symmetric shape's outline has two dominant corners on the same
    /// side of a recursive split's chord (see `candidatePolygon`) — most
    /// noticeable on hexagons and stars, which need more than one corner
    /// resolved per recursive half. This is how many *extra* corners a
    /// simplified outline may have and still be treated as a candidate
    /// for a `sides`-cornered shape, by pruning back down to `sides`. Kept
    /// deliberately small — a circle/ellipse's own simplification is
    /// itself highly symmetric, so a generous tolerance here risks
    /// pruning a circle down to a false-positive "regular" pentagon/
    /// hexagon/star before it ever reaches the ellipse fallback check.
    static let candidateCornerOvershoot = 3
    /// A 5-point star's outer points must sit noticeably farther from the
    /// centroid than its inner points — below this ratio the alternating
    /// pattern is too subtle to distinguish from a slightly lumpy pentagon
    /// or hexagon.
    static let starRadiusRatioThreshold: CGFloat = 1.35
    /// Each segment of a candidate orthogonal polyline must be
    /// overwhelmingly horizontal or vertical — this is the ratio of its
    /// minor-axis extent to its major-axis extent that's still tolerated.
    static let orthogonalAlignmentTolerance: CGFloat = 0.18

    static func classify(points: [CGPoint]) -> ShapeType? {
        guard points.count >= minimumPointsRequired, let first = points.first, let last = points.last else {
            return nil
        }
        let bbox = boundingBox(of: points)
        let diagonal = (bbox.width * bbox.width + bbox.height * bbox.height).squareRoot()
        guard diagonal >= minimumBoundingBoxDiagonal else { return nil }

        let closingGap = distance(first, last)
        let isClosed = closingGap <= diagonal * closureThresholdRatio
        if isClosed {
            return classifyClosed(points: points, closingGap: closingGap, first: first)
        }
        return classifyOpen(points: points, diagonal: diagonal)
    }

    private static func classifyOpen(points: [CGPoint], diagonal: CGFloat) -> ShapeType? {
        if maxDeviationFromLine(points: points) <= diagonal * lineDeviationThresholdRatio {
            return .line
        }
        if detectOrthogonalPolyline(points: points, diagonal: diagonal) != nil {
            return .orthogonalPolyline
        }
        if detectArrow(points: points) != nil {
            return .arrow
        }
        if detectCurvedArrow(points: points) != nil {
            return .curvedArrow
        }
        return nil
    }

    private static func classifyClosed(points: [CGPoint], closingGap: CGFloat, first: CGPoint) -> ShapeType? {
        var closedLoop = points
        if closingGap > 0 { closedLoop.append(first) }
        let diagonal = diagonal(of: points)
        let simplified = douglasPeucker(points: closedLoop, epsilon: diagonal * cornerSimplificationRatio)
        let cornerCount = simplified.count - 1

        let area = enclosedArea(points: simplified)
        guard area > 0 else { return nil }

        if cornerCount == 3 {
            return .triangle
        }
        let rawCorners = Array(simplified.dropLast())
        if let regularPolygonType = classifyRegularPolygon(rawCorners, cornerCount: cornerCount, rawLoop: closedLoop) {
            return regularPolygonType
        }
        if rectangleCornerRange.contains(cornerCount) {
            return .rectangle
        }
        let perimeter = perimeterLength(points: simplified)
        let compactness = (perimeter * perimeter) / (4 * .pi * area)
        return compactness <= circleCompactnessThreshold ? .ellipse : nil
    }

    /// Tries pentagon, hexagon, and star, closest target corner count
    /// first. A circle/ellipse's own Douglas-Peucker simplification is
    /// itself highly symmetric — its "corners" can pass the equal-side/
    /// equal-angle regularity check purely by coincidence, the same way a
    /// regular octagon looks deceptively close to a circle. What actually
    /// separates a genuine polygon corner from an arc DP merely
    /// approximated with straight segments is `hasStraightEdges`: the
    /// *raw*, unsimplified points between two real polygon corners hug a
    /// straight line, while the raw points along a circle's arc
    /// systematically bulge away from the chord connecting its DP
    /// "corners" — that's the actual discriminator, not corner count or
    /// angle regularity alone.
    private static func classifyRegularPolygon(
        _ rawCorners: [CGPoint],
        cornerCount: Int,
        rawLoop: [CGPoint]
    ) -> ShapeType? {
        let targets: [(sides: Int, type: ShapeType)] = [(5, .pentagon), (6, .hexagon), (starVertexCount, .star)]
        let ordered = targets.sorted { abs($0.sides - cornerCount) < abs($1.sides - cornerCount) }
        for target in ordered {
            guard let corners = candidatePolygon(rawCorners, sides: target.sides),
                  hasStraightEdges(rawLoop: rawLoop, corners: corners) else { continue }
            let matches = target.type == .star ? isStarPattern(corners) : isRegularPolygon(corners, sides: target.sides)
            if matches { return target.type }
        }
        return nil
    }

    static func fit(points: [CGPoint]) -> ShapeFit? {
        guard let type = classify(points: points), let first = points.first, let last = points.last else {
            return nil
        }
        switch type {
        case .line, .rectangle, .ellipse, .arrow:
            return fitBasicShape(type, points: points, first: first, last: last)
        case .triangle, .pentagon, .hexagon, .star:
            return fitPolygon(type, points: points)
        case .curvedArrow, .orthogonalPolyline:
            return fitOpenPath(type, points: points)
        }
    }

    private static func fitBasicShape(
        _ type: ShapeType,
        points: [CGPoint],
        first: CGPoint,
        last: CGPoint
    ) -> ShapeFit? {
        switch type {
        case .line:
            return .line(start: first, end: last)
        case .rectangle:
            return .rectangle(rectangleBoundingBox(points: points))
        case .ellipse:
            return .ellipse(boundingBox(of: points))
        case .arrow:
            guard let (tail, head) = detectArrow(points: points) else { return nil }
            return .arrow(tail: tail, head: head)
        default:
            return nil
        }
    }

    private static func fitPolygon(_ type: ShapeType, points: [CGPoint]) -> ShapeFit? {
        switch type {
        case .triangle:
            return triangleFit(points: points)
        case .pentagon:
            return regularPolygonFit(points: points, sides: 5)
        case .hexagon:
            return regularPolygonFit(points: points, sides: 6)
        case .star:
            return starFit(points: points)
        default:
            return nil
        }
    }

    private static func fitOpenPath(_ type: ShapeType, points: [CGPoint]) -> ShapeFit? {
        switch type {
        case .curvedArrow:
            guard let curved = detectCurvedArrow(points: points) else { return nil }
            return .curvedArrow(tail: curved.tail, head: curved.head, control: curved.control)
        case .orthogonalPolyline:
            guard let simplified = detectOrthogonalPolyline(points: points, diagonal: diagonal(of: points)) else {
                return nil
            }
            return .orthogonalPolyline(simplified)
        default:
            return nil
        }
    }

    static func diagonal(of points: [CGPoint]) -> CGFloat {
        let bbox = boundingBox(of: points)
        return (bbox.width * bbox.width + bbox.height * bbox.height).squareRoot()
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
