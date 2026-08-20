import Foundation
import CoreGraphics

struct RecognizedTextObject: Identifiable, Equatable {
    let id: UUID
    var text: String
    var style: TextStyle
    var boundingBox: CGRect
    var sourceStrokeIDs: Set<UUID>

    init(
        id: UUID = UUID(),
        text: String,
        style: TextStyle,
        boundingBox: CGRect,
        sourceStrokeIDs: Set<UUID>
    ) {
        self.id = id
        self.text = text
        self.style = style
        self.boundingBox = boundingBox
        self.sourceStrokeIDs = sourceStrokeIDs
    }
}
