import Testing
import Foundation
@testable import Wrytic

struct PenStrokeFilterTests {
    private func makeStroke(tool: StrokeTool) -> CapturedStroke {
        CapturedStroke(id: UUID(), tool: tool, points: [], boundingBox: .zero, createdAt: .now)
    }

    @Test func keepsOnlyPenStrokes() {
        let pen = makeStroke(tool: .pen)
        let highlighter = makeStroke(tool: .highlighter)
        let shape = makeStroke(tool: .shape)

        let ids = PenStrokeFilter.penStrokeIDs(in: [pen, highlighter, shape])

        #expect(ids == [pen.id])
    }

    @Test func returnsEmptySetWhenNoPenStrokesPresent() {
        let highlighter = makeStroke(tool: .highlighter)
        let shape = makeStroke(tool: .shape)

        let ids = PenStrokeFilter.penStrokeIDs(in: [highlighter, shape])

        #expect(ids.isEmpty)
    }
}
