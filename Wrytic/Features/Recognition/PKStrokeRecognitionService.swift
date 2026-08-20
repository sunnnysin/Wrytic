import PencilKit

actor PKStrokeRecognitionService: HandwritingRecognitionService {
    private let recognizer: PKStrokeRecognizer

    init(preferredLanguages: [Locale.Language]? = nil) {
        recognizer = PKStrokeRecognizer(preferredLanguages: preferredLanguages)
    }

    func updateDrawing(_ drawing: PKDrawing) async {
        await recognizer.updateDrawing(drawing)
    }

    func recognizedText(strokeIDs: Set<UUID>?) async -> String? {
        await recognizer.recognizedText(strokeIDs: strokeIDs)
    }
}
