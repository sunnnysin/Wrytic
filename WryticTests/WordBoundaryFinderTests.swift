import Testing
import Foundation
@testable import Wrytic

struct WordBoundaryFinderTests {
    @Test func offsetInsideFirstWordReturnsThatWord() {
        let range = WordBoundaryFinder.wordRange(in: "hello world", at: 2)

        #expect(range == NSRange(location: 0, length: 5))
    }

    @Test func offsetInsideSecondWordReturnsThatWord() {
        let range = WordBoundaryFinder.wordRange(in: "hello world", at: 7)

        #expect(range == NSRange(location: 6, length: 5))
    }

    @Test func offsetOnWhitespaceReturnsNil() {
        let range = WordBoundaryFinder.wordRange(in: "hello world", at: 5)

        #expect(range == nil)
    }

    @Test func offsetAtStartOfWordReturnsThatWord() {
        let range = WordBoundaryFinder.wordRange(in: "hello world", at: 6)

        #expect(range == NSRange(location: 6, length: 5))
    }

    @Test func negativeOffsetReturnsNil() {
        let range = WordBoundaryFinder.wordRange(in: "hello", at: -1)

        #expect(range == nil)
    }

    @Test func offsetAtOrPastEndReturnsNil() {
        let range = WordBoundaryFinder.wordRange(in: "hello", at: 5)

        #expect(range == nil)
    }

    @Test func emptyTextReturnsNil() {
        let range = WordBoundaryFinder.wordRange(in: "", at: 0)

        #expect(range == nil)
    }

    @Test func threeWordPhraseFindsMiddleWord() {
        let range = WordBoundaryFinder.wordRange(in: "Satyam Kumar Singh", at: 9)

        #expect(range == NSRange(location: 7, length: 5))
    }
}
