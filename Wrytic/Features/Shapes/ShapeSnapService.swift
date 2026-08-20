import PencilKit

enum ShapeSnapService {
    static func snappedStroke(for stroke: PKStroke) -> PKStroke? {
        let originalPoints = Array(stroke.path)
        let locations = originalPoints.map(\.location)
        guard let fit = ShapeClassifier.fit(points: locations) else { return nil }

        let shapePath = ShapePathBuilder.strokePath(
            for: fit,
            creationDate: stroke.path.creationDate,
            pointSize: averageSize(of: originalPoints)
        )
        // stroke.path locations are in the stroke's own pre-transform space;
        // rendering them under the default identity transform instead of
        // the original stroke's transform silently changes the visual
        // size/position of anything built from those coordinates.
        return PKStroke(ink: stroke.ink, path: shapePath, transform: stroke.transform, mask: stroke.mask)
    }

    private static func averageSize(of points: [PKStrokePoint]) -> CGSize {
        guard !points.isEmpty else { return CGSize(width: 4, height: 4) }
        let total = points.reduce(CGSize.zero) { sum, point in
            CGSize(width: sum.width + point.size.width, height: sum.height + point.size.height)
        }
        return CGSize(width: total.width / CGFloat(points.count), height: total.height / CGFloat(points.count))
    }
}
