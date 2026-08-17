import SwiftUI
import PencilKit

struct PencilCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PencilCanvasScrollView {
        let scrollView = PencilCanvasScrollView()
        scrollView.minimumZoomScale = PencilCanvasConfiguration.minimumZoomScale
        scrollView.maximumZoomScale = PencilCanvasConfiguration.maximumZoomScale
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .systemGray5

        PencilCanvasConfiguration.configure(canvasView)

        scrollView.contentSize = canvasView.frame.size
        scrollView.addSubview(canvasView)
        scrollView.canvasView = canvasView
        scrollView.delegate = context.coordinator

        return scrollView
    }

    func updateUIView(_ uiView: PencilCanvasScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? PencilCanvasScrollView)?.canvasView
        }
    }
}
