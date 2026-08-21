import Foundation

/// Applying a new style override drops any existing run that overlaps the
/// new range at all, rather than trying to trim/split them — restyling the
/// same word twice, or restyling a range that crosses an earlier one,
/// always leaves exactly one run covering the new range with no partial
/// leftovers to reconcile.
enum TextRunMerger {
    static func applying(_ newRun: TextRun, to existingRuns: [TextRun]) -> [TextRun] {
        let remaining = existingRuns.filter { !overlaps($0.range, newRun.range) }
        return remaining + [newRun]
    }

    private static func overlaps(_ first: NSRange, _ second: NSRange) -> Bool {
        let firstEnd = first.location + first.length
        let secondEnd = second.location + second.length
        return first.location < secondEnd && second.location < firstEnd
    }
}
