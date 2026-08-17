import Testing
import PencilKit
@testable import Wrytic

struct PencilCanvasConfigurationTests {
    @Test func configureSetsPencilOnlyDrawingPolicy() {
        let canvasView = PKCanvasView()
        PencilCanvasConfiguration.configure(canvasView)
        #expect(canvasView.drawingPolicy == .pencilOnly)
    }

    @Test func configureSetsPageSizeFrame() {
        let canvasView = PKCanvasView()
        PencilCanvasConfiguration.configure(canvasView)
        #expect(canvasView.frame.size == PencilCanvasConfiguration.pageSize)
    }
}
