import CoreGraphics

enum ShapeFit: Equatable {
    case line(start: CGPoint, end: CGPoint)
    case rectangle(CGRect)
    case ellipse(CGRect)
}
