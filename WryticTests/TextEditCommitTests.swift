import Testing
import Foundation
@testable import Wrytic

struct TextEditCommitTests {
    private func makeObject(text: String, runs: [TextRun] = []) -> RecognizedTextObject {
        RecognizedTextObject(
            text: text,
            style: TextStyle.default,
            styleRuns: runs,
            boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20),
            sourceStrokeIDs: []
        )
    }

    @Test func editedTextReplacesOriginalText() {
        let object = makeObject(text: "hello")

        let updated = TextEditCommit.apply(editedText: "hello world", to: object)

        #expect(updated?.text == "hello world")
        #expect(updated?.id == object.id)
    }

    @Test func leadingAndTrailingWhitespaceIsTrimmed() {
        let object = makeObject(text: "hello")

        let updated = TextEditCommit.apply(editedText: "  hello world  \n", to: object)

        #expect(updated?.text == "hello world")
    }

    @Test func emptyEditedTextReturnsNilToSignalDeletion() {
        let object = makeObject(text: "hello")

        let updated = TextEditCommit.apply(editedText: "", to: object)

        #expect(updated == nil)
    }

    @Test func whitespaceOnlyEditedTextReturnsNilToSignalDeletion() {
        let object = makeObject(text: "hello")

        let updated = TextEditCommit.apply(editedText: "   \n  ", to: object)

        #expect(updated == nil)
    }

    @Test func styleAndBoundingBoxAreUnaffected() {
        let object = makeObject(text: "hello")

        let updated = TextEditCommit.apply(editedText: "hi", to: object)

        #expect(updated?.style == object.style)
        #expect(updated?.boundingBox == object.boundingBox)
    }

    @Test func replacingRangeSubstitutesOnlyThatRange() {
        let object = makeObject(text: "hello world")
        let wordRange = NSRange(location: 6, length: 5)

        let updated = TextEditCommit.replacing(range: wordRange, in: object, with: "there")

        #expect(updated?.text == "hello there")
    }

    @Test func replacingFullRangeBehavesLikeWholeTextReplace() {
        let object = makeObject(text: "hello")
        let fullRange = NSRange(location: 0, length: 5)

        let updated = TextEditCommit.replacing(range: fullRange, in: object, with: "goodbye")

        #expect(updated?.text == "goodbye")
    }

    @Test func replacingRangeWithEmptyStringLeavingTextNonEmptyKeepsObject() {
        let object = makeObject(text: "hello world")
        let wordRange = NSRange(location: 0, length: 6)

        let updated = TextEditCommit.replacing(range: wordRange, in: object, with: "")

        #expect(updated?.text == "world")
    }

    @Test func replacingRangeThatEmptiesTheWholeTextSignalsDeletion() {
        let object = makeObject(text: "hello")
        let fullRange = NSRange(location: 0, length: 5)

        let updated = TextEditCommit.replacing(range: fullRange, in: object, with: "  ")

        #expect(updated == nil)
    }

    @Test func replacingOutOfBoundsRangeFallsBackToUnchangedText() {
        let object = makeObject(text: "hi")
        let invalidRange = NSRange(location: 10, length: 5)

        let updated = TextEditCommit.replacing(range: invalidRange, in: object, with: "x")

        #expect(updated?.text == "hi")
    }

    @Test func runsAfterTheEditedRangeShiftByTheLengthDelta() {
        let laterRun = TextRun(range: NSRange(location: 6, length: 5), style: .default)
        let object = makeObject(text: "hi world", runs: [laterRun])
        let editedRange = NSRange(location: 0, length: 2)

        let updated = TextEditCommit.replacing(range: editedRange, in: object, with: "hello")

        #expect(updated?.text == "hello world")
        #expect(updated?.styleRuns.first?.location == 9)
        #expect(updated?.styleRuns.first?.length == 5)
    }

    @Test func runsBeforeTheEditedRangeAreUnaffected() {
        let earlierRun = TextRun(range: NSRange(location: 0, length: 2), style: .default)
        let object = makeObject(text: "hi world", runs: [earlierRun])
        let editedRange = NSRange(location: 3, length: 5)

        let updated = TextEditCommit.replacing(range: editedRange, in: object, with: "there")

        #expect(updated?.styleRuns == [earlierRun])
    }

    @Test func runOverlappingTheEditedRangeIsDropped() {
        let overlappingRun = TextRun(range: NSRange(location: 3, length: 5), style: .default)
        let object = makeObject(text: "hi world", runs: [overlappingRun])
        let editedRange = NSRange(location: 0, length: 4)

        let updated = TextEditCommit.replacing(range: editedRange, in: object, with: "bye")

        #expect(updated?.styleRuns.isEmpty == true)
    }
}
