import SwiftUI

struct NotebookListView: View {
    var store: NotebookStore

    var body: some View {
        if store.notebooks.isEmpty {
            ContentUnavailableView(
                "No Notebooks",
                systemImage: "book.closed",
                description: Text("Tap New Notebook to create your first one.")
            )
        } else {
            List(store.notebooks) { notebook in
                Text(notebook.name)
            }
        }
    }
}
