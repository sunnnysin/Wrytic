import Testing
import PencilKit
@testable import Wrytic

struct PencilCanvasConfigurationTests {
    @Test func configureSetsPencilOnlyDrawingPolicy() {
        let canvasView = PKCanvasView()
        PencilCanvasConfiguration.configure(canvasView)
        #expect(canvasView.drawingPolicy == .pencilOnly)
    }
}
