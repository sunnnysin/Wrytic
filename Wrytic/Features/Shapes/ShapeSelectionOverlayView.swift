import UIKit

/// A Photoshop-style selection box drawn directly in the page's own
/// coordinate space (as a sibling of the canvas inside the shared
/// zoomable page container), so it pans/zooms in lockstep with the
/// canvas with no manual transform math. Reports gestures in that same
/// page-space coordinate system; the caller owns turning those into a
/// resized/moved shape and rebuilding its stroke.
final class ShapeSelectionOverlayView: UIView {
    private static let handleDiameter: CGFloat = 28
    private static let outlineColor = UIColor.systemBlue

    private let outlineLayer = CAShapeLayer()
    private let moveRegion = UIView()
    private let resizeHandle = UIView()

    var onMove: ((_ translationInPageSpace: CGPoint) -> Void)?
    var onResize: ((_ newCornerInPageSpace: CGPoint) -> Void)?
    var onGestureEnded: (() -> Void)?

    init() {
        super.init(frame: .zero)
        // No isUserInteractionEnabled = false here: UIView's default
        // hitTest exits immediately when a view has interaction disabled,
        // before it ever checks subviews - that would make moveRegion and
        // resizeHandle unreachable too, not just the parts of this view
        // with no interactive subview of their own.

        outlineLayer.strokeColor = Self.outlineColor.cgColor
        outlineLayer.fillColor = UIColor.clear.cgColor
        outlineLayer.lineWidth = 1.5
        outlineLayer.lineDashPattern = [5, 4]
        layer.addSublayer(outlineLayer)

        moveRegion.backgroundColor = .clear
        moveRegion.isUserInteractionEnabled = true
        addSubview(moveRegion)
        moveRegion.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleMove(_:))))

        resizeHandle.backgroundColor = Self.outlineColor
        resizeHandle.layer.borderColor = UIColor.white.cgColor
        resizeHandle.layer.borderWidth = 2
        resizeHandle.layer.cornerRadius = Self.handleDiameter / 2
        resizeHandle.isUserInteractionEnabled = true
        addSubview(resizeHandle)
        resizeHandle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleResize(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(boundingBox: CGRect) {
        // The handle is centered on the shape's corner, so half of it sits
        // outside boundingBox. UIView's default hitTest rejects a touch
        // outside its own bounds before it ever looks at subviews, so
        // without this padding only the inner half of the handle - and
        // none of its visually obvious outer half - could actually be
        // grabbed.
        let padding = Self.handleDiameter / 2
        frame = boundingBox.insetBy(dx: -padding, dy: -padding)
        let innerRect = CGRect(x: padding, y: padding, width: boundingBox.width, height: boundingBox.height)

        moveRegion.frame = innerRect
        resizeHandle.frame = CGRect(
            x: innerRect.maxX - Self.handleDiameter / 2,
            y: innerRect.maxY - Self.handleDiameter / 2,
            width: Self.handleDiameter,
            height: Self.handleDiameter
        )
        outlineLayer.frame = bounds
        outlineLayer.path = UIBezierPath(rect: innerRect).cgPath
    }

    @objc private func handleMove(_ gesture: UIPanGestureRecognizer) {
        guard let pageSpace = superview else { return }
        switch gesture.state {
        case .changed:
            onMove?(gesture.translation(in: pageSpace))
        case .ended, .cancelled:
            onGestureEnded?()
        default:
            break
        }
    }

    @objc private func handleResize(_ gesture: UIPanGestureRecognizer) {
        guard let pageSpace = superview else { return }
        switch gesture.state {
        case .changed:
            onResize?(gesture.location(in: pageSpace))
        case .ended, .cancelled:
            onGestureEnded?()
        default:
            break
        }
    }
}
