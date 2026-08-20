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
            return arrowPoints(tail: tail, head: head)
        }
    }

    private static func arrowPoints(tail: CGPoint, head: CGPoint) -> [CGPoint] {
        let dx = head.x - tail.x
        let dy = head.y - tail.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return [tail, head] }

        let reverseDirection = CGPoint(x: -dx / length, y: -dy / length)
        let headLength = min(max(length * arrowHeadLengthRatio, arrowHeadMinimumLength), arrowHeadMaximumLength)
        let flank1 = flankPoint(from: head, direction: reverseDirection, angle: arrowHeadAngle, length: headLength)
        let flank2 = flankPoint(from: head, direction: reverseDirection, angle: -arrowHeadAngle, length: headLength)

        var points = sampledSegments(along: [tail, head])
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
