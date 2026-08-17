import SwiftUI
import PencilKit

struct CanvasScreen: View {
    let notebook: Notebook
    @State private var canvasView = PKCanvasView()

    var body: some View {
        PencilCanvasView(canvasView: $canvasView)
            .ignoresSafeArea()
            .navigationTitle(notebook.name)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("canvasScreen")
    }
}
