import PencilKit
import CoreGraphics

enum ShapePathBuilder {
    private static let timeStep: TimeInterval = 0.004
    private static let arrowHeadAngle: CGFloat = .pi / 7
    private static let arrowHeadLengthRatio: CGFloat = 0.18
    private static let arrowHeadMinimumLength: CGFloat = 14
    private static let arrowHeadMaximumLength: CGFloat = 40

    static func strokePath(for fit: ShapeFit, creationDate: Date, pointSize: CGSize) -> PKStrokePath {
        let locations = controlPointLocations(for: fit)
        let points = locations.enumerated().map { index, location in
            PKStrokePoint(
                location: location,
                timeOffset: TimeInterval(index) * timeStep,
                size: pointSize,
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            )
        }
        return PKStrokePath(controlPoints: points, creationDate: creationDate)
    }

    static func controlPointLocations(for fit: ShapeFit) -> [CGPoint] {
        switch fit {
        case .line(let start, let end):
            return sampledSegments(along: [start, end])
        case .rectangle(let rect):
            let corners = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.minY)
            ]
            return sampledSegments(along: corners)
        case .ellipse(let rect):
            return ellipsePoints(in: rect)
        case .arrow(let tail, let head):
            return arrowPoints(tail: tail, head: head, curveControl: nil)
        case .triangle(let first, let second, let third):
            return sampledSegments(along: [first, second, third, first])
        case .regularPolygon(let center, let radius, let rotation, let sides):
            let vertices = regularPolygonVertices(center: center, radius: radius, rotation: rotation, sides: sides)
            return sampledSegments(along: vertices + [vertices[0]])
        case .star(let center, let outerRadius, let innerRadius, let rotation):
            let vertices = starVertices(
                center: center,
                outerRadius: outerRadius,
                innerRadius: innerRadius,
                rotation: rotation
            )
            return sampledSegments(along: vertices + [vertices[0]])
        case .curvedArrow(let tail, let head, let control):
            return arrowPoints(tail: tail, head: head, curveControl: control)
        case .orthogonalPolyline(let points):
            return sampledSegments(along: points)
        }
    }

    static func regularPolygonVertices(center: CGPoint, radius: CGFloat, rotation: CGFloat, sides: Int) -> [CGPoint] {
        guard sides >= 3 else { return [center] }
        return (0..<sides).map { index in
            let angle = rotation + (CGFloat(index) / CGFloat(sides)) * 2 * .pi
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }

    static func starVertices(
        center: CGPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat,
        rotation: CGFloat
    ) -> [CGPoint] {
        let points = 5
        return (0..<(points * 2)).map { index in
            let angle = rotation + (CGFloat(index) / CGFloat(points * 2)) * 2 * .pi
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }

    /// `curveControl`, when present, bows the shaft through a quadratic
    /// Bézier instead of a straight line — the arrowhead is then oriented
    /// against the curve's own tangent at `head` (via `control`), not the
    /// straight tail-to-head chord, so it still points the way the shaft
    /// is actually arriving.
    private static func arrowPoints(tail: CGPoint, head: CGPoint, curveControl: CGPoint?) -> [CGPoint] {
        let shaft: [CGPoint]
        let tangentOrigin: CGPoint
        if let curveControl {
            shaft = quadraticBezierPoints(from: tail, control: curveControl, to: head, samples: 24)
            tangentOrigin = curveControl
        } else {
            shaft = sampledSegments(along: [tail, head])
            tangentOrigin = tail
        }

        let dx = head.x - tangentOrigin.x
        let dy = head.y - tangentOrigin.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return shaft }

        let reverseDirection = CGPoint(x: -dx / length, y: -dy / length)
        let shaftDx = head.x - tail.x
        let shaftDy = head.y - tail.y
        let shaftLength = (shaftDx * shaftDx + shaftDy * shaftDy).squareRoot()
        let headLength = min(
            max(shaftLength * arrowHeadLengthRatio, arrowHeadMinimumLength),
            arrowHeadMaximumLength
        )
        let flank1 = flankPoint(from: head, direction: reverseDirection, angle: arrowHeadAngle, length: headLength)
        let flank2 = flankPoint(from: head, direction: reverseDirection, angle: -arrowHeadAngle, length: headLength)

        var points = shaft
        points += sampledSegments(along: [head, flank1], samplesPerSegment: 6)
        points += sampledSegments(along: [flank1, head], samplesPerSegment: 6)
        points += sampledSegments(along: [head, flank2], samplesPerSegment: 6)
        return points
    }

    private static func flankPoint(from head: CGPoint, direction: CGPoint, angle: CGFloat, length: CGFloat) -> CGPoint {
        let rotatedX = direction.x * cos(angle) - direction.y * sin(angle)
        let rotatedY = direction.x * sin(angle) + direction.y * cos(angle)
        return CGPoint(x: head.x + rotatedX * length, y: head.y + rotatedY * length)
    }

    static func quadraticBezierPoints(
        from start: CGPoint,
        control: CGPoint,
        to end: CGPoint,
        samples: Int
    ) -> [CGPoint] {
        (0...samples).map { step in
            let fraction = CGFloat(step) / CGFloat(samples)
            let inverse = 1 - fraction
            let x = inverse * inverse * start.x
                + 2 * inverse * fraction * control.x
                + fraction * fraction * end.x
            let y = inverse * inverse * start.y
                + 2 * inverse * fraction * control.y
                + fraction * fraction * end.y
            return CGPoint(x: x, y: y)
        }
    }

    private static func sampledSegments(along corners: [CGPoint], samplesPerSegment: Int = 12) -> [CGPoint] {
        guard corners.count >= 2 else { return corners }
        var result: [CGPoint] = []
        for index in 0..<(corners.count - 1) {
            let start = corners[index]
            let end = corners[index + 1]
            for step in 0..<samplesPerSegment {
                let fraction = CGFloat(step) / CGFloat(samplesPerSegment)
                result.append(CGPoint(
                    x: start.x + (end.x - start.x) * fraction,
                    y: start.y + (end.y - start.y) * fraction
                ))
            }
        }
        result.append(corners[corners.count - 1])
        return result
    }

    private static func ellipsePoints(in rect: CGRect, samples: Int = 60) -> [CGPoint] {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        return (0...samples).map { step in
            let angle = (CGFloat(step) / CGFloat(samples)) * 2 * .pi
            return CGPoint(x: center.x + radiusX * cos(angle), y: center.y + radiusY * sin(angle))
        }
    }
}
