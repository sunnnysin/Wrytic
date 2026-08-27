import CoreGraphics
import Foundation
import PencilKit

struct SelectionGroup: Equatable {
    var strokeIDs: Set<UUID>
    var textObjectIDs: Set<UUID>
    var imageIDs: Set<UUID>
    var boundingBox: CGRect

    var isEmpty: Bool { strokeIDs.isEmpty && textObjectIDs.isEmpty && imageIDs.isEmpty }
    var count: Int { strokeIDs.count + textObjectIDs.count + imageIDs.count }

    /// Resize is only offered when the selection is exactly one image.
    var resizableImageID: UUID? {
        guard strokeIDs.isEmpty, textObjectIDs.isEmpty, imageIDs.count == 1 else { return nil }
        return imageIDs.first
    }

    static func union(of rects: [CGRect]) -> CGRect {
        guard let first = rects.first else { return .zero }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }
}

/// The untouched state captured at drag start; every tick rebuilds from
/// this so the cumulative translation applies to the original geometry.
struct GroupDragBaseline {
    var strokes: [PKStroke]
    var movedStrokeIDs: Set<UUID>
    var textFrames: [UUID: CGRect]
    var imageFrames: [UUID: CGRect]
    var boundingBox: CGRect
}
