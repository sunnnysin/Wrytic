import Testing
import Foundation
@testable import Wrytic

struct NotebookStorePageStyleTests {
    @Test func newNotebookDefaultsToDottedStyle() {
        let store = NotebookStore()
        store.createNotebook()
        #expect(store.notebooks.first?.pageStyle == .dotted)
    }

    @Test func updateStylePersistsForTheCorrectNotebook() {
        let store = NotebookStore()
        store.createNotebook()
        store.createNotebook()
        let targetID = store.notebooks[1].id

        store.updateStyle(for: targetID, style: .grid)

        #expect(store.notebooks[0].pageStyle == .dotted)
        #expect(store.notebooks[1].pageStyle == .grid)
    }

    @Test func updateStyleWithUnknownIDIsNoOp() {
        let store = NotebookStore()
        store.createNotebook()
        let originalStyle = store.notebooks[0].pageStyle

        store.updateStyle(for: UUID(), style: .grid)

        #expect(store.notebooks[0].pageStyle == originalStyle)
    }
}
