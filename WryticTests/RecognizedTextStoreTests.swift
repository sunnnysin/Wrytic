import Testing
import Foundation
@testable import Wrytic

struct RecognizedTextStoreTests {
    private func makeObject() -> RecognizedTextObject {
        RecognizedTextObject(text: "hello", style: .default, boundingBox: .zero, sourceStrokeIDs: [])
    }

    @Test func addAppendsTheObject() {
        let store = RecognizedTextStore()
        let object = makeObject()

        store.add(object)

        #expect(store.textObjects == [object])
    }

    @Test func removeDeletesOnlyTheMatchingObject() {
        let store = RecognizedTextStore()
        let first = makeObject()
        let second = makeObject()
        store.add(first)
        store.add(second)

        store.remove(id: first.id)

        #expect(store.textObjects == [second])
    }

    @Test func removeWithUnknownIDIsNoOp() {
        let store = RecognizedTextStore()
        let object = makeObject()
        store.add(object)

        store.remove(id: UUID())

        #expect(store.textObjects == [object])
    }
}
