import Testing
@testable import Wrytic

struct DrawingToolPickerFactoryTests {
    @Test func toolPickerContainsPenHighlighterAndEraser() {
        let picker = DrawingToolPickerFactory.makeToolPicker()
        #expect(picker.toolItems.count == 3)
    }

    @Test func highlighterIsWiderThanPen() {
        #expect(DrawingToolPickerFactory.defaultHighlighterWidth > DrawingToolPickerFactory.defaultPenWidth)
    }

    @Test func highlighterIsTranslucent() {
        #expect(DrawingToolPickerFactory.highlighterOpacity < 1.0)
    }
}
