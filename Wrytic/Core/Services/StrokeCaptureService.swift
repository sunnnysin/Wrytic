import PencilKit
import CoreGraphics

protocol StrokeCaptureService {
    func capture(from drawing: PKDrawing, shapeSnappedStrokeIDs: Set<UUID>) -> [CapturedStroke]
    func group(_ strokes: [CapturedStroke]) -> [StrokeGroup]
}

extension StrokeCaptureService {
    func capture(from drawing: PKDrawing) -> [CapturedStroke] {
        capture(from: drawing, shapeSnappedStrokeIDs: [])
    }
}

struct PencilKitStrokeCaptureService: StrokeCaptureService {
    /// Vertical gap, in points, within which two strokes' bounding boxes
    /// are still read as sharing a line — handwriting baselines/heights
    /// vary enough that exact y-range overlap alone under-groups them.
    var lineGroupingTolerance: CGFloat = 12

    func capture(from drawing: PKDrawing, shapeSnappedStrokeIDs: Set<UUID> = []) -> [CapturedStroke] {
        drawing.strokes.map { stroke in
            CapturedStroke(
                id: stroke.id,
                tool: StrokeTool.from(stroke, isShapeSnapped: shapeSnappedStrokeIDs.contains(stroke.id)),
                points: stroke.path.map(\.location),
                boundingBox: stroke.renderBounds,
                createdAt: stroke.path.creationDate
            )
        }
    }

    func group(_ strokes: [CapturedStroke]) -> [StrokeGroup] {
        let ordered = strokes.sorted { $0.boundingBox.minY < $1.boundingBox.minY }
        var groups: [[CapturedStroke]] = []

        for stroke in ordered {
            if let index = groups.firstIndex(where: { sharesLine($0, with: stroke) }) {
                groups[index].append(stroke)
            } else {
                groups.append([stroke])
            }
        }

        return groups.map { group in
            StrokeGroup(strokes: group.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
        }
    }

    private func sharesLine(_ group: [CapturedStroke], with stroke: CapturedStroke) -> Bool {
        guard let first = group.first else { return false }
        let union = group.dropFirst().reduce(first.boundingBox) { $0.union($1.boundingBox) }
        let expanded = union.insetBy(dx: 0, dy: -lineGroupingTolerance)
        return expanded.minY <= stroke.boundingBox.maxY && expanded.maxY >= stroke.boundingBox.minY
    }
}
