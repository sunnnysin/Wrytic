import CoreGraphics

extension ShapeClassifier {
    /// Checks that `vertices` (already reduced to exactly `sides` corners)
    /// have roughly equal side lengths and roughly equal interior angles —
    /// what actually separates a genuine hand-drawn pentagon/hexagon from
    /// an irregular shape that merely simplified down to the same corner
    /// count (most commonly a rectangle with one overshoot corner).
    static func isRegularPolygon(_ vertices: [CGPoint], sides: Int) -> Bool {
        guard vertices.count == sides, sides >= 3 else { return false }
        let sideLengths = (0..<sides).map { distance(vertices[$0], vertices[($0 + 1) % sides]) }
        guard coefficientOfVariation(sideLengths) <= regularPolygonToleranceRatio else { return false }

        let angles = (0..<sides).map { index -> CGFloat in
            let previous = vertices[(index - 1 + sides) % sides]
            let current = vertices[index]
            let next = vertices[(index + 1) % sides]
            return interiorAngle(previous: previous, at: current, next: next)
        }
        return coefficientOfVariation(angles) <= regularPolygonToleranceRatio
    }

    /// Whether `vertices` (already reduced to a handful of corners) shows
    /// the alternating near/far-from-centroid pattern a star traces: going
    /// around the loop, radii should alternate between a "high" and "low"
    /// group with a clear gap between the two, rather than staying roughly
    /// uniform (a regular polygon) or varying randomly (a scribble).
    static func isStarPattern(_ vertices: [CGPoint]) -> Bool {
        guard vertices.count >= 6 else { return false }
        let center = centroid(of: vertices)
        let radii = vertices.map { distance($0, center) }
        let sorted = radii.sorted()
        let midpoint = radii.count / 2
        let lowGroup = Array(sorted.prefix(midpoint))
        let highGroup = Array(sorted.suffix(radii.count - midpoint))
        let lowMean = average(lowGroup)
        let highMean = average(highGroup)
        guard lowMean > 0, highMean / lowMean >= starRadiusRatioThreshold else { return false }

        var alternations = 0
        let threshold = (lowMean + highMean) / 2
        var previousIsHigh = radii[0] >= threshold
        for radius in radii.dropFirst() {
            let isHigh = radius >= threshold
            if isHigh != previousIsHigh { alternations += 1 }
            previousIsHigh = isHigh
        }
        return alternations >= vertices.count - 2
    }

    /// Whether the *raw*, unsimplified points between each pair of
    /// consecutive `corners` (as they actually occur, in order, within
    /// `rawLoop`) hug a straight line — a real polygon edge — rather than
    /// systematically bulging away from it, which is what a circle's arc
    /// looks like once Douglas-Peucker has chopped it into straight
    /// segments. `corners` must all be members of `rawLoop`.
    static func hasStraightEdges(rawLoop: [CGPoint], corners: [CGPoint]) -> Bool {
        guard corners.count >= 3 else { return false }
        var indices: [Int] = []
        var searchStart = 0
        for corner in corners {
            guard searchStart < rawLoop.count,
                  let offset = rawLoop[searchStart...].firstIndex(where: { $0 == corner }) else { return false }
            indices.append(offset)
            searchStart = offset
        }

        let tolerance = diagonal(of: rawLoop) * lineDeviationThresholdRatio
        for index in indices.indices {
            let startIndex = indices[index]
            let endIndex = indices[(index + 1) % indices.count]
            let edgePoints: [CGPoint]
            if endIndex > startIndex {
                edgePoints = Array(rawLoop[startIndex...endIndex])
            } else {
                edgePoints = Array(rawLoop[startIndex...]) + Array(rawLoop[0...endIndex])
            }
            guard maxDeviationFromLine(points: edgePoints) <= tolerance else { return false }
        }
        return true
    }

    static func centroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    static func average(_ values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / CGFloat(values.count)
    }

    private static func interiorAngle(previous: CGPoint, at current: CGPoint, next: CGPoint) -> CGFloat {
        let firstVector = CGPoint(x: previous.x - current.x, y: previous.y - current.y)
        let secondVector = CGPoint(x: next.x - current.x, y: next.y - current.y)
        let dot = firstVector.x * secondVector.x + firstVector.y * secondVector.y
        let firstLength = (firstVector.x * firstVector.x + firstVector.y * firstVector.y).squareRoot()
        let secondLength = (secondVector.x * secondVector.x + secondVector.y * secondVector.y).squareRoot()
        guard firstLength > 0, secondLength > 0 else { return 0 }
        let cosine = max(-1, min(1, dot / (firstLength * secondLength)))
        return acos(cosine)
    }

    private static func coefficientOfVariation(_ values: [CGFloat]) -> CGFloat {
        let mean = average(values)
        guard mean > 0 else { return .infinity }
        let variance = values.reduce(CGFloat(0)) { $0 + ($1 - mean) * ($1 - mean) } / CGFloat(values.count)
        return variance.squareRoot() / mean
    }

    static func triangleFit(points: [CGPoint]) -> ShapeFit? {
        guard let simplified = simplifiedClosedCorners(points: points), simplified.count == 3 else { return nil }
        return .triangle(simplified[0], simplified[1], simplified[2])
    }

    static func regularPolygonFit(points: [CGPoint], sides: Int) -> ShapeFit? {
        guard let raw = simplifiedClosedCorners(points: points),
              let corners = candidatePolygon(raw, sides: sides) else { return nil }
        let center = centroid(of: corners)
        let radius = corners.reduce(CGFloat(0)) { $0 + distance($1, center) } / CGFloat(corners.count)
        let rotation = atan2(corners[0].y - center.y, corners[0].x - center.x)
        return .regularPolygon(center: center, radius: radius, rotation: rotation, sides: sides)
    }

    static func starFit(points: [CGPoint]) -> ShapeFit? {
        guard let raw = simplifiedClosedCorners(points: points),
              let corners = candidatePolygon(raw, sides: starVertexCount) else { return nil }
        let center = centroid(of: corners)
        let radii = corners.map { distance($0, center) }
        let sorted = radii.sorted()
        let midpoint = sorted.count / 2
        let innerRadius = average(Array(sorted.prefix(midpoint)))
        let outerRadius = average(Array(sorted.suffix(sorted.count - midpoint)))
        guard let outerIndex = radii.indices.max(by: { radii[$0] < radii[$1] }) else { return nil }
        let rotation = atan2(corners[outerIndex].y - center.y, corners[outerIndex].x - center.x)
        return .star(center: center, outerRadius: outerRadius, innerRadius: innerRadius, rotation: rotation)
    }

    private static func simplifiedClosedCorners(points: [CGPoint]) -> [CGPoint]? {
        guard let first = points.first else { return nil }
        var closedLoop = points
        if let last = points.last, last != first { closedLoop.append(first) }
        let epsilon = diagonal(of: points) * cornerSimplificationRatio
        return Array(douglasPeucker(points: closedLoop, epsilon: epsilon).dropLast())
    }

    /// `corners` is a candidate for a `sides`-cornered regular shape if its
    /// count is at least `sides` and not more than `sides +
    /// candidateCornerOvershoot` over — outside that range it's neither a
    /// plausible match nor safe to force down to `sides` without discarding
    /// real structure. Within range, pruned back to exactly `sides` via
    /// `dominantCorners` when Douglas-Peucker kept extra nearly-colinear
    /// points (see `candidateCornerOvershoot`'s doc comment).
    static func candidatePolygon(_ corners: [CGPoint], sides: Int) -> [CGPoint]? {
        guard corners.count >= sides, corners.count <= sides + candidateCornerOvershoot else { return nil }
        return corners.count == sides ? corners : dominantCorners(corners, keeping: sides)
    }

    /// Repeatedly removes whichever vertex is least "corner-like" (its
    /// interior angle closest to a straight 180°) until only `count`
    /// remain — a simple greedy simplification that recovers a shape's true
    /// dominant corners when Douglas-Peucker's single-split-per-level
    /// recursion spuriously kept an extra, nearly-colinear sample point.
    static func dominantCorners(_ points: [CGPoint], keeping count: Int) -> [CGPoint] {
        var remaining = points
        while remaining.count > count {
            var weakestIndex = 0
            var weakestDeviationFromStraight = CGFloat.greatestFiniteMagnitude
            for index in remaining.indices {
                let previous = remaining[(index - 1 + remaining.count) % remaining.count]
                let current = remaining[index]
                let next = remaining[(index + 1) % remaining.count]
                let deviation = abs(.pi - interiorAngle(previous: previous, at: current, next: next))
                if deviation < weakestDeviationFromStraight {
                    weakestDeviationFromStraight = deviation
                    weakestIndex = index
                }
            }
            remaining.remove(at: weakestIndex)
        }
        return remaining
    }

    /// A hand-drawn rectangle's corners are where the pencil sharply
    /// changes direction, and that's exactly where people tend to
    /// overshoot slightly before correcting — a small spike past the true
    /// corner that a plain min/max bounding box takes at face value,
    /// inflating the fitted rectangle. When the corner-detection pass
    /// found a 5th vertex (the tolerance for a rectangle at all), it's
    /// almost always that overshoot, not a genuine 5th corner, so the
    /// bounding box is built from whichever 4 of those 5 vertices are
    /// smallest — dropping the outlier shrinks the box the most.
    static func rectangleBoundingBox(points: [CGPoint]) -> CGRect {
        let bbox = boundingBox(of: points)
        guard let corners = simplifiedClosedCorners(points: points), corners.count == 5 else { return bbox }

        var bestBox = bbox
        for skipIndex in corners.indices {
            let subset = corners.enumerated().filter { $0.offset != skipIndex }.map(\.element)
            let candidateBox = boundingBox(of: subset)
            if candidateBox.width * candidateBox.height < bestBox.width * bestBox.height {
                bestBox = candidateBox
            }
        }
        return bestBox
    }
}
