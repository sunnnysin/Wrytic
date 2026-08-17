import SwiftUI
import PencilKit

struct ContentView: View {
    @State private var canvasView = PKCanvasView()
    @State private var recognizedText = ""
    @State private var debounceTask: Task<Void, Never>?
    private let recognizer = PKStrokeRecognizer()

    var body: some View {
        VStack(spacing: 0) {
            Text(recognizedText.isEmpty ? "Write with the Pencil…" : recognizedText)
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                .padding()
                .background(Color(.secondarySystemBackground))

            CanvasRepresentable(canvasView: $canvasView) {
                scheduleRecognition()
            }
        }
    }

    private func scheduleRecognition() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await recognizer.updateDrawing(canvasView.drawing)
            let text = await recognizer.recognizedText()
            recognizedText = text ?? ""
        }
    }
}

#Preview {
    ContentView()
}
