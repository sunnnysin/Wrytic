import Foundation

@Observable
final class NotebookStore {
    private(set) var notebooks: [Notebook] = []

    func createNotebook() {
        notebooks.append(Notebook(name: "Untitled Notebook \(notebooks.count + 1)"))
    }

    func updateStyle(for id: Notebook.ID, style: PageStyle) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }) else { return }
        notebooks[index].pageStyle = style
    }
}
