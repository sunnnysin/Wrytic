import Testing
import Foundation
import PencilKit
@testable import Wrytic

struct PKStrokeRecognitionServiceTests {
    @Test func recognizedTextIsNilForEmptyDrawing() async {
        let service = PKStrokeRecognitionService()
        await service.updateDrawing(PKDrawing())

        let text = await service.recognizedText(strokeIDs: nil)

        #expect(text == nil)
    }

    @Test func recognizedTextIsNilForUnknownStrokeIDs() async {
        let service = PKStrokeRecognitionService()
        await service.updateDrawing(PKDrawing())

        let text = await service.recognizedText(strokeIDs: [UUID()])

        #expect(text == nil)
    }

    @Test func repeatedCallsAfterAFailureStillReturnAResult() async {
        let service = PKStrokeRecognitionService()
        await service.updateDrawing(PKDrawing())

        let first = await service.recognizedText(strokeIDs: nil)
        let retry = await service.recognizedText(strokeIDs: nil)

        #expect(first == retry)
    }
}
