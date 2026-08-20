import Testing
import Foundation
import PencilKit
@testable import Wrytic

private actor RecordingRecognitionService: HandwritingRecognitionService {
    private(set) var requestedStrokeIDs: [Set<UUID>] = []
    private(set) var recognizedTextCallCount = 0
    var response: String?

    init(response: String?) {
        self.response = response
    }

    func updateDrawing(_ drawing: PKDrawing) async {}

    func recognizedText(strokeIDs: Set<UUID>?) async -> String? {
        recognizedTextCallCount += 1
        if let strokeIDs { requestedStrokeIDs.append(strokeIDs) }
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

    private func makeWorkflow(response: String?) -> (AutoRecognitionWorkflow, RecordingRecognitionService) {
        let recognizer = RecordingRecognitionService(response: response)
        let workflow = AutoRecognitionWorkflow(makeRecognitionService: { recognizer })
        return (workflow, recognizer)
    }

    @Test func mixedPenAndHighlighterOnlySendsPenStrokesToRecognizer() async {
        let pen = makeStroke(origin: CGPoint(x: 0, y: 0), inkType: .pen)
        let highlighter = makeStroke(origin: CGPoint(x: 0, y: 20), inkType: .marker)
        let drawing = PKDrawing(strokes: [pen, highlighter])
        let (workflow, recognizer) = makeWorkflow(response: "hello")

        let results = await workflow.process(drawing: drawing, shapeSnappedStrokeIDs: [], style: .default)

        #expect(await recognizer.requestedStrokeIDs == [[pen.id]])
        #expect(results.map(\.text) == ["hello"])
        #expect(results.first?.sourceStrokeIDs == [pen.id])
    }

    @Test func shapeSnappedPenStrokeIsExcludedFromRecognition() async {
        let pen = makeStroke(origin: CGPoint(x: 0, y: 0), inkType: .pen)
        let shapeSnapped = makeStroke(origin: CGPoint(x: 0, y: 5), inkType: .pen)
        let drawing = PKDrawing(strokes: [pen, shapeSnapped])
        let (workflow, recognizer) = makeWorkflow(response: "hello")

        _ = await workflow.process(
            drawing: drawing,
            shapeSnappedStrokeIDs: [shapeSnapped.id],
            style: .default
        )

        #expect(await recognizer.requestedStrokeIDs == [[pen.id]])
    }

    @Test func noPenStrokesSkipsRecognitionEntirely() async {
        let highlighter = makeStroke(origin: .zero, inkType: .marker)
        let drawing = PKDrawing(strokes: [highlighter])
        let (workflow, recognizer) = makeWorkflow(response: "hello")

        let results = await workflow.process(drawing: drawing, shapeSnappedStrokeIDs: [], style: .default)

        #expect(results.isEmpty)
        #expect(await recognizer.recognizedTextCallCount == 0)
    }

    @Test func failedRecognitionYieldsNoResults() async {
        let pen = makeStroke(origin: .zero, inkType: .pen)
        let drawing = PKDrawing(strokes: [pen])
        let (workflow, _) = makeWorkflow(response: nil)

        let results = await workflow.process(drawing: drawing, shapeSnappedStrokeIDs: [], style: .default)

        #expect(results.isEmpty)
    }

    @Test func resultBoundingBoxUnionsOnlyPenStrokes() async {
        let pen = makeStroke(origin: CGPoint(x: 0, y: 0), inkType: .pen)
        let highlighter = makeStroke(origin: CGPoint(x: 500, y: 500), inkType: .marker)
        let drawing = PKDrawing(strokes: [pen, highlighter])
        let (workflow, _) = makeWorkflow(response: "hello")

        let results = await workflow.process(drawing: drawing, shapeSnappedStrokeIDs: [], style: .default)

        #expect(results.first?.boundingBox.contains(CGPoint(x: 500, y: 500)) == false)
    }

    @Test func strokesOnDistinctLinesProduceSeparateRecognitionResults() async {
        let firstLine = makeStroke(origin: CGPoint(x: 0, y: 0), inkType: .pen)
        let secondLine = makeStroke(origin: CGPoint(x: 0, y: 300), inkType: .pen)
        let drawing = PKDrawing(strokes: [firstLine, secondLine])
        let (workflow, recognizer) = makeWorkflow(response: "hello")

        let results = await workflow.process(drawing: drawing, shapeSnappedStrokeIDs: [], style: .default)

        #expect(results.count == 2)
        #expect(await recognizer.recognizedTextCallCount == 2)
        #expect(Set(results.flatMap(\.sourceStrokeIDs)) == [firstLine.id, secondLine.id])
    }

    @Test func strokesOnSameLineAreRecognizedTogetherInOneCall() async {
        let firstWord = makeStroke(origin: CGPoint(x: 0, y: 0), inkType: .pen)
        let secondWord = makeStroke(origin: CGPoint(x: 60, y: 2), inkType: .pen)
        let drawing = PKDrawing(strokes: [firstWord, secondWord])
        let (workflow, recognizer) = makeWorkflow(response: "hello world")

        let results = await workflow.process(drawing: drawing, shapeSnappedStrokeIDs: [], style: .default)

        #expect(results.count == 1)
        #expect(results.first?.sourceStrokeIDs == [firstWord.id, secondWord.id])
        #expect(await recognizer.recognizedTextCallCount == 1)
    }
}
