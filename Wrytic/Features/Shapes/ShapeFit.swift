import CoreGraphics

enum ShapeFit: Equatable {
    case line(start: CGPoint, end: CGPoint)
    case rectangle(CGRect)
    case ellipse(CGRect)
    case arrow(tail: CGPoint, head: CGPoint)
    case triangle(CGPoint, CGPoint, CGPoint)
    /// A regular polygon snapped to a circle of `radius` centered on
    /// `center`, with its first vertex at `rotation` radians from the
    /// positive x-axis — used for both pentagon and hexagon, which differ
    /// only in `sides`.
    case regularPolygon(center: CGPoint, radius: CGFloat, rotation: CGFloat, sides: Int)
    case star(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, rotation: CGFloat)
    case curvedArrow(tail: CGPoint, head: CGPoint, control: CGPoint)
    case orthogonalPolyline([CGPoint])
}
