import CoreGraphics

extension ShapeFit {
    private static let minimumLineBoundingBoxThickness: CGFloat = 24
    private static let minimumSize: CGFloat = 20
    private static let minimumRadius: CGFloat = 10

    var boundingBox: CGRect {
        switch self {
        case .rectangle(let rect), .ellipse(let rect):
            return rect
        case .line(let start, let end), .arrow(let start, let end):
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            return rect.insetBy(
                dx: -max(0, (Self.minimumLineBoundingBoxThickness - rect.width) / 2),
                dy: -max(0, (Self.minimumLineBoundingBoxThickness - rect.height) / 2)
            )
        case .triangle(let first, let second, let third):
            return ShapeClassifier.boundingBox(of: [first, second, third])
        case .regularPolygon(let center, let radius, _, _):
            return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        case .star(let center, let outerRadius, _, _):
            return CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )
        case .curvedArrow(let tail, let head, let control):
            return ShapeClassifier.boundingBox(of: [tail, head, control])
        case .orthogonalPolyline(let points):
            return ShapeClassifier.boundingBox(of: points)
        }
    }

    func translated(by delta: CGPoint) -> ShapeFit {
        switch self {
        case .rectangle(let rect):
            return .rectangle(rect.offsetBy(dx: delta.x, dy: delta.y))
        case .ellipse(let rect):
            return .ellipse(rect.offsetBy(dx: delta.x, dy: delta.y))
        case .line(let start, let end):
            return .line(start: start.offset(by: delta), end: end.offset(by: delta))
        case .arrow(let tail, let head):
            return .arrow(tail: tail.offset(by: delta), head: head.offset(by: delta))
        case .triangle(let first, let second, let third):
            return .triangle(first.offset(by: delta), second.offset(by: delta), third.offset(by: delta))
        case .regularPolygon(let center, let radius, let rotation, let sides):
            return .regularPolygon(center: center.offset(by: delta), radius: radius, rotation: rotation, sides: sides)
        case .star(let center, let outerRadius, let innerRadius, let rotation):
            return .star(
                center: center.offset(by: delta),
                outerRadius: outerRadius,
                innerRadius: innerRadius,
                rotation: rotation
            )
        case .curvedArrow(let tail, let head, let control):
            return .curvedArrow(
                tail: tail.offset(by: delta),
                head: head.offset(by: delta),
                control: control.offset(by: delta)
            )
        case .orthogonalPolyline(let points):
            return .orthogonalPolyline(points.map { $0.offset(by: delta) })
        }
    }

    /// Resizes by moving whichever defining point sits nearer the current
    /// bottom-right corner of the shape to `newCorner`, keeping the
    /// opposite point fixed — the standard "drag the corner handle" model.
    func resized(draggingCornerTo newCorner: CGPoint) -> ShapeFit {
        switch self {
        case .rectangle(let rect):
            return .rectangle(Self.resizedRect(rect, cornerTo: newCorner))
        case .ellipse(let rect):
            return .ellipse(Self.resizedRect(rect, cornerTo: newCorner))
        case .line(let start, let end):
            let (anchor, dragged) = Self.anchorAndDragged(start, end)
            let resizedPoint = Self.clamped(dragged: newCorner, awayFrom: anchor)
            return dragged == end ? .line(start: anchor, end: resizedPoint) : .line(start: resizedPoint, end: anchor)
        case .arrow(let tail, let head):
            let (anchor, dragged) = Self.anchorAndDragged(tail, head)
            let resizedPoint = Self.clamped(dragged: newCorner, awayFrom: anchor)
            return dragged == head ? .arrow(tail: anchor, head: resizedPoint) : .arrow(tail: resizedPoint, head: anchor)
        case .triangle(let first, let second, let third):
            let points = Self.scaled([first, second, third], boundingBox: boundingBox, cornerTo: newCorner)
            return .triangle(points[0], points[1], points[2])
        case .regularPolygon(let center, let radius, let rotation, let sides):
            let newRadius = max(Self.minimumRadius, Self.distance(center, newCorner) / 2.squareRoot())
            return .regularPolygon(center: center, radius: newRadius, rotation: rotation, sides: sides)
        case .star(let center, let outerRadius, let innerRadius, let rotation):
            let newOuterRadius = max(Self.minimumRadius, Self.distance(center, newCorner) / 2.squareRoot())
            let ratio = outerRadius > 0 ? newOuterRadius / outerRadius : 1
            return .star(
                center: center,
                outerRadius: newOuterRadius,
                innerRadius: innerRadius * ratio,
                rotation: rotation
            )
        case .curvedArrow(let tail, let head, let control):
            let (anchor, dragged) = Self.anchorAndDragged(tail, head)
            let resizedPoint = Self.clamped(dragged: newCorner, awayFrom: anchor)
            let delta = CGPoint(x: resizedPoint.x - dragged.x, y: resizedPoint.y - dragged.y)
            let newControl = control.offset(by: delta)
            return dragged == head
                ? .curvedArrow(tail: anchor, head: resizedPoint, control: newControl)
                : .curvedArrow(tail: resizedPoint, head: anchor, control: newControl)
        case .orthogonalPolyline(let points):
            return .orthogonalPolyline(Self.scaled(points, boundingBox: boundingBox, cornerTo: newCorner))
        }
    }

    private static func resizedRect(_ rect: CGRect, cornerTo newCorner: CGPoint) -> CGRect {
        let anchor = CGPoint(x: rect.minX, y: rect.minY)
        let clamped = clamped(dragged: newCorner, awayFrom: anchor)
        return CGRect(x: anchor.x, y: anchor.y, width: clamped.x - anchor.x, height: clamped.y - anchor.y)
    }

    /// Scales every point in `points` from `boundingBox`'s top-left corner
    /// so that corner moving to `newCorner` matches — the same model as
    /// `resizedRect`, generalized to an arbitrary point set instead of a
    /// single rect.
    private static func scaled(_ points: [CGPoint], boundingBox: CGRect, cornerTo newCorner: CGPoint) -> [CGPoint] {
        let anchor = CGPoint(x: boundingBox.minX, y: boundingBox.minY)
        let clamped = clamped(dragged: newCorner, awayFrom: anchor)
        let scaleX = boundingBox.width > 0 ? (clamped.x - anchor.x) / boundingBox.width : 1
        let scaleY = boundingBox.height > 0 ? (clamped.y - anchor.y) / boundingBox.height : 1
        return points.map {
            CGPoint(x: anchor.x + ($0.x - anchor.x) * scaleX, y: anchor.y + ($0.y - anchor.y) * scaleY)
        }
    }

    private static func anchorAndDragged(_ pointA: CGPoint, _ pointB: CGPoint) -> (anchor: CGPoint, dragged: CGPoint) {
        (pointA.x + pointA.y) > (pointB.x + pointB.y) ? (pointB, pointA) : (pointA, pointB)
    }

    private static func clamped(dragged: CGPoint, awayFrom anchor: CGPoint) -> CGPoint {
        let dx = dragged.x - anchor.x
        let dy = dragged.y - anchor.y
        let clampedDx = dx < 0 ? min(dx, -minimumSize) : max(dx, minimumSize)
        let clampedDy = dy < 0 ? min(dy, -minimumSize) : max(dy, minimumSize)
        return CGPoint(x: anchor.x + clampedDx, y: anchor.y + clampedDy)
    }

    private static func distance(_ pointA: CGPoint, _ pointB: CGPoint) -> CGFloat {
        ((pointA.x - pointB.x) * (pointA.x - pointB.x) + (pointA.y - pointB.y) * (pointA.y - pointB.y)).squareRoot()
    }
}

private extension CGPoint {
    func offset(by delta: CGPoint) -> CGPoint {
        CGPoint(x: x + delta.x, y: y + delta.y)
    }
}
