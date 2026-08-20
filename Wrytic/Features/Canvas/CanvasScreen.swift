import SwiftUI
import PencilKit

struct CanvasScreen: View {
    let notebookID: Notebook.ID
    var store: NotebookStore
    var fontSettings: FontSettingsStore
    var recognitionSettings: RecognitionSettingsStore
    @State private var canvasView = PKCanvasView()
    @State private var textStore = RecognizedTextStore()

    private var notebook: Notebook? {
        store.notebooks.first { $0.id == notebookID }
    }

    var body: some View {
        PencilCanvasView(
            canvasView: $canvasView,
            pageStyle: notebook?.pageStyle ?? .dotted,
            fontSettings: fontSettings,
            recognitionSettings: recognitionSettings,
            textStore: textStore
        )
            .ignoresSafeArea()
            .navigationTitle(notebook?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("canvasScreen")
            .toolbar {
                ToolbarItem {
                    Menu {
                        ForEach(PageStyle.allCases) { style in
                            Button(style.displayName) {
                                store.updateStyle(for: notebookID, style: style)
                            }
                        }
                    } label: {
                        Label("Page Style", systemImage: "square.grid.2x2")
                    }
                    .accessibilityIdentifier("pageStyleMenu")
                }
            }
    }
}
