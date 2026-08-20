import UIKit

final class PageStyleBackgroundView: UIView {
    var style: PageStyle = .dotted {
        didSet {
            guard style != oldValue else { return }
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isOpaque = true
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setStrokeColor(UIColor.systemGray4.cgColor)
        context.setLineWidth(1)

        switch style {
        case .blank:
            break

        case .lined:
            for y in PageStylePatternGenerator.horizontalLineYPositions(pageHeight: bounds.height) {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: bounds.width, y: y))
            }
            context.strokePath()

        case .dotted:
            context.setFillColor(UIColor.systemGray3.cgColor)
            for point in PageStylePatternGenerator.dotPositions(pageSize: bounds.size) {
                context.fillEllipse(in: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2))
            }

        case .grid:
            for x in PageStylePatternGenerator.gridLineXPositions(pageWidth: bounds.width) {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: bounds.height))
            }
            for y in PageStylePatternGenerator.gridLineYPositions(pageHeight: bounds.height) {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: bounds.width, y: y))
            }
            context.strokePath()
        }
    }
}
