import Testing
import Foundation
@testable import Wrytic

struct TextRunMergerTests {
    private func makeRun(location: Int, length: Int, size: CGFloat = 20) -> TextRun {
        var style = TextStyle.default
        style.size = size
        return TextRun(range: NSRange(location: location, length: length), style: style)
    }

    @Test func addingToEmptyRunsJustAppends() {
        let newRun = makeRun(location: 0, length: 5)

        let result = TextRunMerger.applying(newRun, to: [])

        #expect(result == [newRun])
    }

    @Test func nonOverlappingRunsAreBothKept() {
        let existing = makeRun(location: 0, length: 5)
        let newRun = makeRun(location: 10, length: 5)

        let result = TextRunMerger.applying(newRun, to: [existing])

        #expect(Set(result.map(\.id)) == [existing.id, newRun.id])
    }

    @Test func exactlyOverlappingRunReplacesTheOldOne() {
        let existing = makeRun(location: 0, length: 5, size: 20)
        let newRun = makeRun(location: 0, length: 5, size: 32)

        let result = TextRunMerger.applying(newRun, to: [existing])

        #expect(result == [newRun])
    }

    @Test func partiallyOverlappingRunDropsTheOldOneEntirely() {
        let existing = makeRun(location: 0, length: 10)
        let newRun = makeRun(location: 5, length: 10)

        let result = TextRunMerger.applying(newRun, to: [existing])

        #expect(result == [newRun])
    }

    @Test func adjacentButNotOverlappingRunsAreBothKept() {
        let existing = makeRun(location: 0, length: 5)
        let newRun = makeRun(location: 5, length: 5)

        let result = TextRunMerger.applying(newRun, to: [existing])

        #expect(Set(result.map(\.id)) == [existing.id, newRun.id])
    }
}
