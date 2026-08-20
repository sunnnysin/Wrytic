import PencilKit
import CoreGraphics
import os

private let workflowLog = Logger(subsystem: "com.wrytic.app", category: "recognition-workflow")

struct AutoRecognitionWorkflow: HandwritingWorkflowService {
    var captureService: StrokeCaptureService = PencilKitStrokeCaptureService()
    /// A fresh recognizer per recognition attempt, rather than one reused
    /// for the whole canvas session — the SDK documents scoping a single
    /// loaded drawing to multiple strokeID subsets as intended usage, but
    /// says nothing about accuracy across a long-lived instance fed a
    /// growing/shrinking drawing over many separate calls over time, so
    /// this stays conservative rather than risking accumulated state.
    var makeRecognitionService: @Sendable () -> HandwritingRecognitionService = { PKStrokeRecognitionService() }

    func process(
        drawing: PKDrawing,
        shapeSnappedStrokeIDs: Set<UUID>,
        style: TextStyle
    ) async -> [RecognizedTextObject] {
        let captured = captureService.capture(from: drawing, shapeSnappedStrokeIDs: shapeSnappedStrokeIDs)
        let penIDs = PenStrokeFilter.penStrokeIDs(in: captured)
        let penStrokes = captured.filter { penIDs.contains($0.id) }
        workflowLog.debug("process() captured=\(captured.count) penStrokes=\(penStrokes.count)")
        guard !penStrokes.isEmpty else { return [] }

        // Recognizing per spatial line/group, rather than every pen stroke
        // on the page as one flat blob, keeps unrelated content from
        // bleeding into a single recognition call — a garbled result on
        // one line doesn't drag in or corrupt a different line. Each call
        // only ever sees ink that hasn't been converted yet — converted
        // strokes are removed from the canvas — so re-recognizing
        // previously-converted text together with new ink (and risking
        // the recognizer garbling the combination) never comes up.
        let groups = captureService.group(penStrokes)
        let recognitionService = makeRecognitionService()
        await recognitionService.updateDrawing(drawing)

        var results: [RecognizedTextObject] = []
        for (index, group) in groups.enumerated() {
            let strokeIDs = Set(group.strokes.map(\.id))
            let text = await recognitionService.recognizedText(strokeIDs: strokeIDs)
            let logged = text ?? "nil"
            workflowLog.debug("  group[\(index)] strokeIDs=\(strokeIDs.count) text=\(logged, privacy: .public)")
            guard let text else { continue }
            results.append(RecognizedTextObject(
                text: text,
                style: style,
                boundingBox: group.boundingBox,
                sourceStrokeIDs: strokeIDs
            ))
        }
        return results
    }
}
