import CoreGraphics

extension ShapeFit {
    private static let minimumLineBoundingBoxThickness: CGFloat = 24
    private static let minimumSize: CGFloat = 20

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
        }
    }

    private static func resizedRect(_ rect: CGRect, cornerTo newCorner: CGPoint) -> CGRect {
        let anchor = CGPoint(x: rect.minX, y: rect.minY)
        let clamped = clamped(dragged: newCorner, awayFrom: anchor)
        return CGRect(x: anchor.x, y: anchor.y, width: clamped.x - anchor.x, height: clamped.y - anchor.y)
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
}

private extension CGPoint {
    func offset(by delta: CGPoint) -> CGPoint {
        CGPoint(x: x + delta.x, y: y + delta.y)
    }
}
