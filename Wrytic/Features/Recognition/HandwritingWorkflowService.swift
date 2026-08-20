import PencilKit

protocol HandwritingWorkflowService: Sendable {
    func process(
        drawing: PKDrawing,
        shapeSnappedStrokeIDs: Set<UUID>,
        style: TextStyle
    ) async -> RecognizedTextObject?
}
