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

    /// Replaces just the given range (typically the user's current word/
    /// text selection, from `UITextView.selectedRange`) rather than the
    /// whole object's text — the "type a replacement for the highlighted
    /// word" flow. Existing `styleRuns` are shifted to stay aligned with
    /// their original text: runs entirely before the edit are untouched,
    /// runs entirely after are shifted by the length delta, and any run
    /// the edit itself overlaps is dropped — its original text no longer
    /// exists in the same form to keep styling. Falls through to the same
    /// empty-result-deletes-the-object rule as `apply(editedText:to:)`.
    static func replacing(
        range: NSRange,
        in object: RecognizedTextObject,
        with replacement: String
    ) -> RecognizedTextObject? {
        let current = object.text as NSString
        guard range.location != NSNotFound, range.location + range.length <= current.length else {
            return apply(editedText: object.text, to: object)
        }
        let newText = current.replacingCharacters(in: range, with: replacement)
        let delta = (replacement as NSString).length - range.length
        var updated = object
        updated.styleRuns = adjustRuns(object.styleRuns, replacedRange: range, delta: delta)
        return apply(editedText: newText, to: updated)
    }

    private static func adjustRuns(_ runs: [TextRun], replacedRange: NSRange, delta: Int) -> [TextRun] {
        let replacedEnd = replacedRange.location + replacedRange.length
        return runs.compactMap { run in
            let runEnd = run.location + run.length
            if runEnd <= replacedRange.location {
                return run
            }
            if run.location >= replacedEnd {
                var shifted = run
                shifted.location += delta
                return shifted
            }
            return nil
        }
    }
}
