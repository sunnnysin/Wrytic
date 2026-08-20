import Foundation
import CoreGraphics

struct StrokeGroup: Identifiable, Equatable {
    let id: UUID
    let strokes: [CapturedStroke]

    init(id: UUID = UUID(), strokes: [CapturedStroke]) {
        self.id = id
        self.strokes = strokes
    }

    var boundingBox: CGRect {
        guard let first = strokes.first else { return .zero }
        return strokes.dropFirst().reduce(first.boundingBox) { $0.union($1.boundingBox) }
    }
}
