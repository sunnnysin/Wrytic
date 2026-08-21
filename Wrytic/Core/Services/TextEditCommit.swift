import Foundation

enum TextEditCommit {
    /// Committing an edit that leaves the object empty removes it — an
    /// empty text object has no visible frame to re-select from, so
    /// leaving one behind is a dead end rather than a real empty state.
    /// `nil` means "delete `object`," matching how Notes-style apps treat
    /// clearing a text box's contents down to nothing.
    static func apply(editedText: String, to object: RecognizedTextObject) -> RecognizedTextObject? {
        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var updated = object
        updated.text = trimmed
        return updated
    }
}
