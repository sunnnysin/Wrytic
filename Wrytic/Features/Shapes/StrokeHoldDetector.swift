import PencilKit

enum StrokeHoldDetector {
    static let minimumHoldDuration: TimeInterval = 0.35
    static let maximumMovement: CGFloat = 8

    static func isHeldStillAtEnd(points: [PKStrokePoint]) -> Bool {
        guard let first = points.first, let last = points.last else { return false }
        let totalDuration = last.timeOffset - first.timeOffset
        guard totalDuration >= minimumHoldDuration else { return false }

        let holdStartTime = last.timeOffset - minimumHoldDuration
        let trailingPoints = points.filter { $0.timeOffset >= holdStartTime }
        guard let anchor = trailingPoints.first, trailingPoints.count >= 2 else { return false }

        return trailingPoints.allSatisfy { ShapeClassifier.distance($0.location, anchor.location) <= maximumMovement }
    }
}
