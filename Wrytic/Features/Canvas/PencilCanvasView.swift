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
        /// How long the drawing must go unchanged after a stroke ends
        /// before that stroke is evaluated for shape-snapping. This is a
        /// real wall-clock debounce, not an inspection of the stroke's
        /// own recorded point timestamps — PencilKit doesn't reliably
        /// keep generating points while the Pencil is held still, so a
        /// point-timing-based "hold" check is unreliable in practice.
        static let shapeSnapDebounceDelay: TimeInterval = 0.4
        /// How long the pencil must stay down without adding new points
        /// before a stroke counts as "held" and becomes eligible for
        /// snapping at all. Without this, any closed shape or straight
        /// line gets snapped shortly after every lift, even a quick doodle
        /// drawn with no pause — the gesture is draw-AND-hold, not just draw.
        static let holdDetectionDelay: TimeInterval = 0.35

        let toolPicker = DrawingToolPickerFactory.makeToolPicker()
        var backgroundView: PageStyleBackgroundView?
        private var snappedStrokeIDs: Set<UUID> = []
        private var pendingSnapWorkItem: DispatchWorkItem?
        private var holdDetectionWorkItem: DispatchWorkItem?
        private var isToolInUse = false
        private var heldDuringCurrentStroke = false

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? PencilCanvasScrollView)?.pageContainer
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isToolInUse = true
            heldDuringCurrentStroke = false
            scheduleHoldDetection()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isToolInUse = false
            holdDetectionWorkItem?.cancel()
            scheduleSnapIfNeeded(in: canvasView)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            pendingSnapWorkItem?.cancel()
            if isToolInUse {
                // Still moving — a genuine hold requires no new points for
                // holdDetectionDelay while the pencil stays down, so any
                // further movement resets that clock.
                scheduleHoldDetection()
                return
            }
            // Pressure data lags touch data, so PencilKit can still deliver a
            // final, corrected version of the stroke after the pencil lifts
            // (canvasViewDidEndUsingTool already fired). Scheduling from
            // changes that land while the pencil is still down snaps against
            // not-yet-final geometry, and the later correction then arrives
            // as an unsnapped stroke and gets reclassified from scratch —
            // sometimes crossing the rectangle/ellipse threshold the other
            // way. Only scheduling once the tool is no longer in use avoids
            // classifying anything but the finished stroke.
            scheduleSnapIfNeeded(in: canvasView)
        }

        private func scheduleHoldDetection() {
            holdDetectionWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.heldDuringCurrentStroke = true
            }
            holdDetectionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdDetectionDelay, execute: workItem)
        }

        private func scheduleSnapIfNeeded(in canvasView: PKCanvasView) {
            guard heldDuringCurrentStroke else { return }
            guard let lastStroke = canvasView.drawing.strokes.last,
                  !snappedStrokeIDs.contains(lastStroke.id) else { return }

            let strokeID = lastStroke.id
            let workItem = DispatchWorkItem { [weak self, weak canvasView] in
                guard let self, let canvasView else { return }
                self.attemptSnap(strokeID: strokeID, in: canvasView)
            }
            pendingSnapWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.shapeSnapDebounceDelay, execute: workItem)
        }

        private func attemptSnap(strokeID: UUID, in canvasView: PKCanvasView) {
            guard let lastStroke = canvasView.drawing.strokes.last, lastStroke.id == strokeID else { return }

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
