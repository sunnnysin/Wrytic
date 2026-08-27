import CoreGraphics
import Foundation

enum LassoHitTesting {
    static let enclosureThreshold: CGFloat = 0.6

    struct Candidate {
        let id: UUID
        let samplePoints: [CGPoint]
    }

    static func selected(within lasso: [CGPoint], from candidates: [Candidate]) -> Set<UUID> {
        var selected: Set<UUID> = []
        for candidate in candidates where encloses(lasso, candidate.samplePoints) {
            selected.insert(candidate.id)
        }
        return selected
    }

    static func encloses(_ lasso: [CGPoint], _ samplePoints: [CGPoint]) -> Bool {
        guard lasso.count >= 3, !samplePoints.isEmpty else { return false }
        let inside = samplePoints.reduce(into: 0) { count, point in
            if ShapeGeometry.pointInPolygon(point, lasso) { count += 1 }
        }
        return CGFloat(inside) / CGFloat(samplePoints.count) >= enclosureThreshold
    }

    static func sampleRect(_ rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.midY),
            CGPoint(x: rect.midX, y: rect.midY)
        ]
    }

    static func bounds(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
