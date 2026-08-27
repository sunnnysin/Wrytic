import UIKit

/// Covers the canvas while lasso mode is on, in the page's own coordinate
/// space. Draws the in-progress loop and, once a group is selected, its
/// move/resize chrome; the coordinator turns the callbacks into content
/// changes.
final class LassoOverlayView: UIView {
    private enum Mode { case lasso, move, resize }

    private static let handleDiameter: CGFloat = 28

    private let lassoLayer = CAShapeLayer()
    private let selectionLayer = CAShapeLayer()
    private let resizeHandle = UIView()

    private var lassoPoints: [CGPoint] = []
    private var selectionBox: CGRect?
    private var allowResize = false
    private var mode: Mode = .lasso

    var onLassoComplete: ((_ loopInPageSpace: [CGPoint]) -> Void)?
    var onMove: ((_ translationInPageSpace: CGPoint) -> Void)?
    var onResize: ((_ newCornerInPageSpace: CGPoint) -> Void)?
    var onGestureEnded: (() -> Void)?
    var onTapOutsideSelection: (() -> Void)?

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear

        lassoLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.08).cgColor
        lassoLayer.strokeColor = UIColor.systemBlue.cgColor
        lassoLayer.lineWidth = 1.5
        lassoLayer.lineDashPattern = [4, 4]
        layer.addSublayer(lassoLayer)

        selectionLayer.fillColor = UIColor.clear.cgColor
        selectionLayer.strokeColor = UIColor.systemBlue.cgColor
        selectionLayer.lineWidth = 1.5
        selectionLayer.lineDashPattern = [5, 4]
        layer.addSublayer(selectionLayer)

        resizeHandle.backgroundColor = .systemBlue
        resizeHandle.layer.borderColor = UIColor.white.cgColor
        resizeHandle.layer.borderWidth = 2
        resizeHandle.layer.cornerRadius = Self.handleDiameter / 2
        resizeHandle.frame = CGRect(x: 0, y: 0, width: Self.handleDiameter, height: Self.handleDiameter)
        resizeHandle.isHidden = true
        addSubview(resizeHandle)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.pencil.rawValue),
            NSNumber(value: UITouch.TouchType.direct.rawValue)
        ]
        addGestureRecognizer(pan)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func showLasso() {
        selectionBox = nil
        allowResize = false
        resizeHandle.isHidden = true
        selectionLayer.path = nil
    }

    func showSelection(boundingBox: CGRect, allowResize: Bool) {
        lassoPoints = []
        lassoLayer.path = nil
        self.allowResize = allowResize
        updateSelection(boundingBox: boundingBox)
        resizeHandle.isHidden = !allowResize
    }

    func updateSelection(boundingBox: CGRect) {
        selectionBox = boundingBox
        selectionLayer.path = UIBezierPath(rect: boundingBox).cgPath
        resizeHandle.center = CGPoint(x: boundingBox.maxX, y: boundingBox.maxY)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            mode = modeForTouch(at: point)
            if mode == .lasso {
                lassoPoints = [point]
                selectionBox = nil
                selectionLayer.path = nil
                resizeHandle.isHidden = true
            }
        case .changed:
            switch mode {
            case .lasso:
                lassoPoints.append(point)
                redrawLasso()
            case .move:
                onMove?(gesture.translation(in: self))
            case .resize:
                onResize?(point)
            }
        case .ended, .cancelled:
            switch mode {
            case .lasso:
                let loop = lassoPoints
                lassoPoints = []
                lassoLayer.path = nil
                onLassoComplete?(loop)
            case .move, .resize:
                onGestureEnded?()
            }
            mode = .lasso
        default:
            break
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let box = selectionBox else { return }
        let point = gesture.location(in: self)
        if box.insetBy(dx: -8, dy: -8).contains(point) { return }
        if allowResize, resizeHandle.frame.insetBy(dx: -8, dy: -8).contains(point) { return }
        onTapOutsideSelection?()
    }

    private func modeForTouch(at point: CGPoint) -> Mode {
        if allowResize, resizeHandle.frame.insetBy(dx: -12, dy: -12).contains(point) { return .resize }
        if let box = selectionBox, box.insetBy(dx: -8, dy: -8).contains(point) { return .move }
        return .lasso
    }

    private func redrawLasso() {
        guard lassoPoints.count >= 2 else { return }
        let path = UIBezierPath()
        path.move(to: lassoPoints[0])
        for point in lassoPoints.dropFirst() { path.addLine(to: point) }
        path.close()
        lassoLayer.path = path.cgPath
    }
}
