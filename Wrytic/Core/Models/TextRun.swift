import Foundation

/// A style override for a sub-range of a `RecognizedTextObject`'s text —
/// what lets font/size/weight/color changes made against a double-tap/
/// hold word selection apply to just that word instead of the whole
/// object. `NSRange` itself isn't used as stored state since it isn't
/// reliably `Equatable`/`Codable` across Foundation versions; `location`/
/// `length` are the source of truth, `range` is a convenience.
struct TextRun: Identifiable, Equatable {
    var id: UUID
    var location: Int
    var length: Int
    var style: TextStyle

    var range: NSRange { NSRange(location: location, length: length) }

    init(id: UUID = UUID(), range: NSRange, style: TextStyle) {
        self.id = id
        self.location = range.location
        self.length = range.length
        self.style = style
    }
}
