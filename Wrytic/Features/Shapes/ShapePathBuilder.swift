import PencilKit
import CoreGraphics

enum ShapePathBuilder {
    private static let timeStep: TimeInterval = 0.004
    private static let pointSize = CGSize(width: 4, height: 4)

    static func strokePath(for fit: ShapeFit, creationDate: Date) -> PKStrokePath {
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
