import Foundation

enum PenStrokeFilter {
    static func penStrokeIDs(in strokes: [CapturedStroke]) -> Set<UUID> {
        Set(strokes.filter { $0.tool == .pen }.map(\.id))
    }
}
