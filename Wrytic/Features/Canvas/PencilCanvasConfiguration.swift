import PencilKit

enum PencilCanvasConfiguration {
    static let pageSize = CGSize(width: 1600, height: 2200)
    static let minimumZoomScale: CGFloat = 0.5
    static let maximumZoomScale: CGFloat = 4.0

    static func configure(_ canvasView: PKCanvasView) {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .white
        canvasView.isOpaque = true
        canvasView.frame = CGRect(origin: .zero, size: pageSize)
    }
}
