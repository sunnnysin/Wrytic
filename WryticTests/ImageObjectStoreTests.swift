import Testing
import Foundation
@testable import Wrytic

struct ImageObjectStoreTests {
    private func makeObject() -> ImageObject {
        ImageObject(imageData: Data([0x01, 0x02]), frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    @Test func addAppendsTheObject() {
        let store = ImageObjectStore()
        let object = makeObject()

        store.add(object)

        #expect(store.imageObjects == [object])
    }

    @Test func updateReplacesTheMatchingObject() {
        let store = ImageObjectStore()
        var object = makeObject()
        store.add(object)

        object.frame = CGRect(x: 10, y: 10, width: 200, height: 200)
        store.update(object)

        #expect(store.imageObjects == [object])
    }

    @Test func removeDeletesOnlyTheMatchingObject() {
        let store = ImageObjectStore()
        let first = makeObject()
        let second = makeObject()
        store.add(first)
        store.add(second)

        store.remove(id: first.id)

        #expect(store.imageObjects == [second])
    }

    @Test func removeWithUnknownIDIsNoOp() {
        let store = ImageObjectStore()
        let object = makeObject()
        store.add(object)

        store.remove(id: UUID())

        #expect(store.imageObjects == [object])
    }
}
