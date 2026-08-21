import UIKit

/// Builds the actual displayed text for a `RecognizedTextObject`: its base
/// `style` applied to the whole string, then each `styleRuns` override
/// layered on top for whatever range the user restyled via a word/range
/// selection. This is what makes per-word font/size/weight/color changes
/// (as opposed to whole-object ones) actually render differently.
enum AttributedTextRenderer {
    static func render(
        _ object: RecognizedTextObject,
        using availabilityService: FontAvailabilityService
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: object.text,
            attributes: attributes(for: object.style, using: availabilityService)
        )
        let fullRange = NSRange(location: 0, length: (object.text as NSString).length)
        for run in object.styleRuns {
            guard let clamped = clamp(run.range, to: fullRange) else { continue }
            result.setAttributes(attributes(for: run.style, using: availabilityService), range: clamped)
        }
        return result
    }

    private static func attributes(
        for style: TextStyle,
        using availabilityService: FontAvailabilityService
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: availabilityService.resolvedUIFont(for: style.font, weight: style.weight, size: style.size),
            .foregroundColor: style.color.uiColor
        ]
    }

    private static func clamp(_ range: NSRange, to bounds: NSRange) -> NSRange? {
        let start = max(range.location, bounds.location)
        let end = min(range.location + range.length, bounds.location + bounds.length)
        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }
}
