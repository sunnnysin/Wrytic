import Testing
import Foundation
import UIKit
@testable import Wrytic

struct AttributedTextRendererTests {
    private let availabilityService: FontAvailabilityService = SystemFontAvailabilityService()

    private func makeObject(text: String, runs: [TextRun] = []) -> RecognizedTextObject {
        RecognizedTextObject(
            text: text,
            style: TextStyle.default,
            styleRuns: runs,
            boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20),
            sourceStrokeIDs: []
        )
    }

    @Test func wholeStringUsesBaseStyleWhenNoRuns() {
        let object = makeObject(text: "hello world")

        let attributed = AttributedTextRenderer.render(object, using: availabilityService)

        let color = attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(color == TextStyle.default.color.uiColor)
    }

    @Test func runOverridesColorOnlyWithinItsRange() {
        var runStyle = TextStyle.default
        runStyle.color = .red
        let run = TextRun(range: NSRange(location: 6, length: 5), style: runStyle)
        let object = makeObject(text: "hello world", runs: [run])

        let attributed = AttributedTextRenderer.render(object, using: availabilityService)

        let insideColor = attributed.attribute(.foregroundColor, at: 7, effectiveRange: nil) as? UIColor
        let outsideColor = attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(TextColor(uiColor: insideColor ?? .clear) == TextColor.red)
        #expect(TextColor(uiColor: outsideColor ?? .clear) == TextStyle.default.color)
    }

    @Test func runSizeOverridesFontOnlyWithinItsRange() {
        var runStyle = TextStyle.default
        runStyle.size = 40
        let run = TextRun(range: NSRange(location: 0, length: 5), style: runStyle)
        let object = makeObject(text: "hello world", runs: [run])

        let attributed = AttributedTextRenderer.render(object, using: availabilityService)

        let insideFont = attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let outsideFont = attributed.attribute(.font, at: 6, effectiveRange: nil) as? UIFont
        #expect(insideFont?.pointSize == 40)
        #expect(outsideFont?.pointSize == TextStyle.default.size)
    }

    @Test func runOutOfBoundsIsIgnored() {
        let run = TextRun(range: NSRange(location: 50, length: 5), style: TextStyle.default)
        let object = makeObject(text: "hi", runs: [run])

        let attributed = AttributedTextRenderer.render(object, using: availabilityService)

        #expect(attributed.string == "hi")
    }
}
