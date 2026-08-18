import SwiftUI

struct HomeView: View {
    var store: NotebookStore

    var body: some View {
        NavigationStack {
            NotebookListView(store: store)
                .navigationTitle("Notebooks")
                .toolbar {
                    ToolbarItem {
                        Button("New Notebook", systemImage: "plus") {
                            store.createNotebook()
                        }
                        .accessibilityIdentifier("newNotebookButton")
                    }
                }
                .navigationDestination(for: Notebook.self) { notebook in
                    CanvasScreen(notebookID: notebook.id, store: store)
                }
        }
    }
}
