import CoreGraphics

extension ShapeFit {
    var isClosed: Bool {
        switch self {
        case .rectangle, .ellipse:
            return true
        case .line, .arrow:
            return false
        }
    }

    /// Whether `point` should count as "on this shape" for tap-to-deselect
    /// purposes — checked against the shape's actual visible geometry
    /// (with a small tolerance), not its bounding box. A diagonal line or
    /// arrow's bounding box can cover most of the page even though the
    /// visible ink is a thin stroke; using the bounding box for the
    /// deselect check meant almost any tap "elsewhere" on the page still
    /// registered as tapping the shape, and it never deselected.
    func isNear(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        let outline = ShapePathBuilder.controlPointLocations(for: self)
        guard outline.count >= 2 else { return false }
        if isClosed {
            return ShapeGeometry.pointInPolygon(point, outline)
                || ShapeGeometry.distanceToPolyline(point, outline, closed: true) <= tolerance
        }
        return ShapeGeometry.distanceToPolyline(point, outline, closed: false) <= tolerance
    }
}
