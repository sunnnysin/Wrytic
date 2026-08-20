import PencilKit

protocol HandwritingRecognitionService {
    func updateDrawing(_ drawing: PKDrawing) async
    func recognizedText(strokeIDs: Set<UUID>?) async -> String?
}
