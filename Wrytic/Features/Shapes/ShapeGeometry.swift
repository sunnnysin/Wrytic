import CoreGraphics

/// Generic point/polyline math shared by every `ShapeFit` case for
/// tap-to-deselect purposes (`ShapeFit.isNear`) — kept shape-agnostic so
/// adding a new `ShapeFit` case never needs new hit-testing math of its
/// own, only a `ShapePathBuilder.controlPointLocations` entry.
enum ShapeGeometry {
    static func distanceToPolyline(_ point: CGPoint, _ points: [CGPoint], closed: Bool) -> CGFloat {
        guard points.count >= 2 else { return .greatestFiniteMagnitude }
        var minDistance = CGFloat.greatestFiniteMagnitude
        let segmentCount = closed ? points.count : points.count - 1
        for index in 0..<segmentCount {
            let start = points[index]
            let end = points[(index + 1) % points.count]
            minDistance = min(minDistance, distanceToSegment(point, start, end))
        }
        return minDistance
    }

    /// Standard ray-casting point-in-polygon test.
    static func pointInPolygon(_ point: CGPoint, _ polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var isInside = false
        var previousIndex = polygon.count - 1
        for index in 0..<polygon.count {
            let current = polygon[index]
            let previous = polygon[previousIndex]
            if (current.y > point.y) != (previous.y > point.y),
               point.x < (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x {
                isInside.toggle()
            }
            previousIndex = index
        }
        return isInside
    }

    private static func distanceToSegment(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let fraction = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projectedX = start.x + fraction * dx
        let projectedY = start.y + fraction * dy
        return hypot(point.x - projectedX, point.y - projectedY)
    }
}
