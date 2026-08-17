import SwiftUI
import PencilKit

struct PencilCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var pageStyle: PageStyle

    func makeUIView(context: Context) -> PencilCanvasScrollView {
        let scrollView = PencilCanvasScrollView()
        scrollView.minimumZoomScale = PencilCanvasConfiguration.minimumZoomScale
        scrollView.maximumZoomScale = PencilCanvasConfiguration.maximumZoomScale
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .systemGray5
        scrollView.contentSize = PencilCanvasConfiguration.pageSize
        scrollView.delegate = context.coordinator

        let pageContainer = UIView(frame: CGRect(origin: .zero, size: PencilCanvasConfiguration.pageSize))
        pageContainer.backgroundColor = .clear

        let backgroundView = PageStyleBackgroundView(frame: pageContainer.bounds)
        backgroundView.style = pageStyle
        pageContainer.addSubview(backgroundView)

        PencilCanvasConfiguration.configure(canvasView)
        canvasView.frame = pageContainer.bounds
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isScrollEnabled = false
        pageContainer.addSubview(canvasView)

        scrollView.addSubview(pageContainer)
        scrollView.pageContainer = pageContainer
        context.coordinator.backgroundView = backgroundView

        canvasView.delegate = context.coordinator

        context.coordinator.toolPicker.setVisible(true, forFirstResponder: canvasView)
        context.coordinator.toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        return scrollView
    }

    func updateUIView(_ uiView: PencilCanvasScrollView, context: Context) {
        context.coordinator.backgroundView?.style = pageStyle
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
        let toolPicker = DrawingToolPickerFactory.makeToolPicker()
        var backgroundView: PageStyleBackgroundView?
        private var snappedStrokeIDs: Set<UUID> = []

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? PencilCanvasScrollView)?.pageContainer
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let lastStroke = canvasView.drawing.strokes.last,
                  !snappedStrokeIDs.contains(lastStroke.id) else { return }

            guard let snapped = ShapeSnapService.snappedStroke(for: lastStroke) else {
                snappedStrokeIDs.insert(lastStroke.id)
                return
            }

            snappedStrokeIDs.insert(snapped.id)
            var strokes = canvasView.drawing.strokes
            strokes[strokes.count - 1] = snapped
            canvasView.drawing = PKDrawing(strokes: strokes)
        }
    }
}
