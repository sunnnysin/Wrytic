import Foundation

/// Finds the word range at a character offset — the pure half of
/// double-tap/hold-to-select-a-word. Deliberately not using UITextView's
/// own native word-selection gesture: that requires `isSelectable = true`
/// at rest, which was found to compete with (and reliably beat) the
/// custom pan gesture used for whole-object drag-to-move. Driving word
/// selection through our own gestures instead keeps `isSelectable` off
/// except for the brief window a word selection is actually active, so
/// move never has a competing gesture recognizer to lose to.
enum WordBoundaryFinder {
    static func wordRange(in text: String, at utf16Offset: Int) -> NSRange? {
        let string = text as NSString
        guard string.length > 0, utf16Offset >= 0, utf16Offset < string.length else { return nil }

        var result: NSRange?
        let fullRange = NSRange(location: 0, length: string.length)
        string.enumerateSubstrings(in: fullRange, options: .byWords) { _, range, _, stop in
            if range.location <= utf16Offset, utf16Offset < range.location + range.length {
                result = range
                stop.pointee = true
            }
        }
        return result
    }
}
