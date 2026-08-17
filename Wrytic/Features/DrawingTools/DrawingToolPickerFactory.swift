import PencilKit
import UIKit

enum DrawingToolPickerFactory {
    static let penColors: [UIColor] = [.black, .systemBlue, .systemRed, .systemGreen, .systemPurple]
    static let highlighterColors: [UIColor] = [.systemYellow, .systemGreen, .systemPink, .systemBlue]

    static let defaultPenWidth = PKInkingTool.InkType.pen.defaultWidth
    static let defaultHighlighterWidth = PKInkingTool.InkType.marker.defaultWidth * 2
    static let highlighterOpacity: CGFloat = 0.4

    static let penIdentifier = "wrytic.pen"
    static let highlighterIdentifier = "wrytic.highlighter"

    static func makeToolPicker() -> PKToolPicker {
        let penItem = PKToolPickerInkingItem(
            type: .pen,
            color: penColors[0],
            width: defaultPenWidth,
            identifier: penIdentifier
        )
        let highlighterItem = PKToolPickerInkingItem(
            type: .marker,
            color: highlighterColors[0].withAlphaComponent(highlighterOpacity),
            width: defaultHighlighterWidth,
            identifier: highlighterIdentifier
        )
        let vectorEraser = PKToolPickerEraserItem(type: .vector)
        let bitmapEraser = PKToolPickerEraserItem(type: .bitmap)

        return PKToolPicker(toolItems: [penItem, highlighterItem, vectorEraser, bitmapEraser])
    }
}
