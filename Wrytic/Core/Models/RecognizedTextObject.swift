import Foundation
import CoreGraphics

struct RecognizedTextObject: Identifiable, Equatable {
    let id: UUID
    var text: String
    var style: TextStyle
    /// Per-range overrides layered on top of `style` — a word/range the
    /// user restyled via double-tap/hold selection, rather than the
    /// object-wide style change from a plain single-tap selection.
    var styleRuns: [TextRun]
    var boundingBox: CGRect
    var sourceStrokeIDs: Set<UUID>

    init(
        id: UUID = UUID(),
        text: String,
        style: TextStyle,
        styleRuns: [TextRun] = [],
        boundingBox: CGRect,
        sourceStrokeIDs: Set<UUID>
    ) {
        self.id = id
        self.text = text
        self.style = style
        self.styleRuns = styleRuns
        self.boundingBox = boundingBox
        self.sourceStrokeIDs = sourceStrokeIDs
    }
}
