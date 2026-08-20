import PencilKit
import CoreGraphics

struct AutoRecognitionWorkflow: HandwritingWorkflowService {
    var captureService: StrokeCaptureService = PencilKitStrokeCaptureService()
    var recognitionService: HandwritingRecognitionService = PKStrokeRecognitionService()

    func process(
        drawing: PKDrawing,
        shapeSnappedStrokeIDs: Set<UUID>,
        style: TextStyle
    ) async -> RecognizedTextObject? {
        let captured = captureService.capture(from: drawing, shapeSnappedStrokeIDs: shapeSnappedStrokeIDs)
        let penIDs = PenStrokeFilter.penStrokeIDs(in: captured)
        guard !penIDs.isEmpty else { return nil }

        await recognitionService.updateDrawing(drawing)
        guard let text = await recognitionService.recognizedText(strokeIDs: penIDs) else { return nil }

        let boundingBox = captured
            .filter { penIDs.contains($0.id) }
            .map(\.boundingBox)
            .reduce(CGRect?.none) { $0?.union($1) ?? $1 } ?? .zero

        return RecognizedTextObject(text: text, style: style, boundingBox: boundingBox, sourceStrokeIDs: penIDs)
    }
}
