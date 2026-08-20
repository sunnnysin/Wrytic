import PencilKit

protocol HandwritingRecognitionService: Sendable {
    func updateDrawing(_ drawing: PKDrawing) async
    func recognizedText(strokeIDs: Set<UUID>?) async -> String?
}
