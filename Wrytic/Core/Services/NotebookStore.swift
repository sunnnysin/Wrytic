import Foundation

@Observable
final class NotebookStore {
    private(set) var notebooks: [Notebook] = []

    func createNotebook() {
        notebooks.append(Notebook(name: "Untitled Notebook \(notebooks.count + 1)"))
    }
}
