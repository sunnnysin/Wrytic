import Testing
import Foundation
@testable import Wrytic

struct TextEditCommitTests {
    private func makeObject(text: String) -> RecognizedTextObject {
        RecognizedTextObject(
            text: text,
            style: TextStyle.default,
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
}
