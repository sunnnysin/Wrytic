import PencilKit

enum ShapeSnapService {
    static func snappedStroke(for stroke: PKStroke) -> PKStroke? {
        let points = Array(stroke.path)
        guard StrokeHoldDetector.isHeldStillAtEnd(points: points) else { return nil }

        let locations = points.map(\.location)
        guard let fit = ShapeClassifier.fit(points: locations) else { return nil }

        let shapePath = ShapePathBuilder.strokePath(for: fit, creationDate: stroke.path.creationDate)
        return PKStroke(ink: stroke.ink, path: shapePath)
    }
}
