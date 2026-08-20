import Testing
import Foundation
import PencilKit
@testable import Wrytic

private actor RecordingRecognitionService: HandwritingRecognitionService {
    private(set) var lastRequestedStrokeIDs: Set<UUID>?
    private(set) var recognizedTextCallCount = 0
    var response: String?

    init(response: String?) {
        self.response = response
    }

    func updateDrawing(_ drawing: PKDrawing) async {}

    func recognizedText(strokeIDs: Set<UUID>?) async -> String? {
        recognizedTextCallCount += 1
        lastRequestedStrokeIDs = strokeIDs
        return response
    }
}

struct AutoRecognitionWorkflowTests {
    private func makePoint(x: CGFloat, y: CGFloat) -> PKStrokePoint {
        PKStrokePoint(
            location: CGPoint(x: x, y: y),
            timeOffset: 0,
            size: CGSize(width: 2, height: 2),
            opacity: 1,
            force: 1,
            azimuth: 0,
            altitude: 0
        )
    }

    private func makeStroke(origin: CGPoint, inkType: PKInkingTool.InkType) -> PKStroke {
        let points = [makePoint(x: origin.x, y: origin.y), makePoint(x: origin.x + 40, y: origin.y + 10)]
        let path = PKStrokePath(controlPoints: points, creationDate: .now)
        return PKStroke(ink: PKInk(inkType, color: .black), path: path)
    }

    @Test func mixedPenAndHighlighterOnlySendsPenStrokesToRecognizer() async {
        let pen = makeStroke(origin: CGPoint(x: 0, y: 0), inkType: .pen)
        let highlighter = makeStroke(origin: CGPoint(x: 0, y: 20), inkType: .marker)
        let drawing = PKDrawing(strokes: [pen, highlighter])
        let recognizer = RecordingRecognitionService(response: "hello")
        let workflow = AutoRecognitionWorkflow(recognitionService: recognizer)

        let result = await workflow.process(drawing: drawing, shapeSnappedStrokeIDs: [], style: .default)

        #expect(await recognizer.lastRequestedStrokeIDs == [pen.id])
        #expect(result?.text == "hello")
        #expect(result?.sourceStrokeIDs == [pen.id])
    }

    @Test func shapeSnappedPenStrokeIsExcludedFromRecognition() async {
        let pen = makeStroke(origin: CGPoint(x: 0, y: 0), inkType: .pen)
        let shapeSnapped = makeStroke(origin: CGPoint(x: 0, y: 20), inkType: .pen)
        let drawing = PKDrawing(strokes: [pen, shapeSnapped])
        let recognizer = RecordingRecognitionService(response: "hello")
        let workflow = AutoRecognitionWorkflow(recognitionService: recognizer)

        _ = await workflow.process(
            drawing: drawing,
            shapeSnappedStrokeIDs: [shapeSnapped.id],
            style: .default
        )

        #expect(await recognizer.lastRequestedStrokeIDs == [pen.id])
    }

    @Test func noPenStrokesSkipsRecognitionEntirely() async {
        let highlighter = makeStroke(origin: .zero, inkType: .marker)
        let drawing = PKDrawing(strokes: [highlighter])
        let recognizer = RecordingRecognitionService(response: "hello")
        let workflow = AutoRecognitionWorkflow(recognitionService: recognizer)

        let result = await workflow.process(drawing: drawing, shapeSnappedStrokeIDs: [], style: .default)

        #expect(result == nil)
        #expect(await recognizer.recognizedTextCallCount == 0)
    }

    @Test func failedRecognitionReturnsNil() async {
        let pen = makeStroke(origin: .zero, inkType: .pen)
        let drawing = PKDrawing(strokes: [pen])
        let recognizer = RecordingRecognitionService(response: nil)
        let workflow = AutoRecognitionWorkflow(recognitionService: recognizer)

        let result = await workflow.process(drawing: drawing, shapeSnappedStrokeIDs: [], style: .default)

        #expect(result == nil)
    }

    @Test func resultBoundingBoxUnionsOnlyPenStrokes() async {
        let pen = makeStroke(origin: CGPoint(x: 0, y: 0), inkType: .pen)
        let highlighter = makeStroke(origin: CGPoint(x: 500, y: 500), inkType: .marker)
        let drawing = PKDrawing(strokes: [pen, highlighter])
        let recognizer = RecordingRecognitionService(response: "hello")
        let workflow = AutoRecognitionWorkflow(recognitionService: recognizer)

        let result = await workflow.process(drawing: drawing, shapeSnappedStrokeIDs: [], style: .default)

        #expect(result?.boundingBox.contains(CGPoint(x: 500, y: 500)) == false)
    }
}
