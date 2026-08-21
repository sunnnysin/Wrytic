import SwiftUI
import PencilKit

struct PencilCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var pageStyle: PageStyle
    var fontSettings: FontSettingsStore
    var recognitionSettings: RecognitionSettingsStore
    var textStore: RecognizedTextStore

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
        context.coordinator.pageContainer = pageContainer

        let deselectTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDeselectTap(_:))
        )
        deselectTap.cancelsTouchesInView = false
        pageContainer.addGestureRecognizer(deselectTap)

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
        Coordinator(fontSettings: fontSettings, recognitionSettings: recognitionSettings, textStore: textStore)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate, UITextViewDelegate {
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
        /// Long enough to let a whole word (or short phrase) get written
        /// before recognition fires — a short debounce fires mid-word,
        /// sending isolated letters/fragments to the recognizer with no
        /// lexical context to disambiguate them, which tanks accuracy far
        /// more than it would for real handwriting. Resets on every new
        /// stroke, so continuous writing just keeps pushing this out —
        /// only genuine pauses of this length trigger it.
        static let recognitionDebounceDelay: TimeInterval = 3.0

        let toolPicker = DrawingToolPickerFactory.makeToolPicker()
        var backgroundView: PageStyleBackgroundView?
        weak var pageContainer: UIView?
        var snappedStrokeIDs: Set<UUID> = []
        /// Every stroke that has already gone through a snap attempt,
        /// regardless of outcome — guards against re-running
        /// `attemptSnap` on the same stroke. Deliberately separate from
        /// `snappedStrokeIDs`, which must only ever contain strokes that
        /// were actually turned into a shape: `snappedStrokeIDs` is what
        /// gets reported to the recognition pipeline as "not handwriting",
        /// and conflating the two silently dropped any handwritten stroke
        /// that simply paused at the end from ever reaching the recognizer.
        private var snapEvaluatedStrokeIDs: Set<UUID> = []
        private var pendingSnapWorkItem: DispatchWorkItem?
        private var holdDetectionWorkItem: DispatchWorkItem?
        private var isToolInUse = false
        private var heldDuringCurrentStroke = false

        private var selectionOverlay: ShapeSelectionOverlayView?
        private var selectedStrokeID: UUID?
        private var selectedFit: ShapeFit?
        private var selectedOriginalStroke: PKStroke?
        private var selectedOriginalPoints: [PKStrokePoint] = []
        private var dragStartFit: ShapeFit?
        private weak var activeCanvasView: PKCanvasView?
        /// Set while a selection-driven update writes to canvasView.drawing,
        /// so that write's own canvasViewDrawingDidChange callback doesn't
        /// re-enter the auto-snap debounce pipeline and try to reclassify
        /// a shape that's already been fitted.
        private var isApplyingSelectionUpdate = false

        let fontSettings: FontSettingsStore
        let recognitionSettings: RecognitionSettingsStore
        let textStore: RecognizedTextStore
        let recognitionWorkflow: HandwritingWorkflowService = AutoRecognitionWorkflow()
        let availabilityService: FontAvailabilityService = SystemFontAvailabilityService()
        var pendingRecognitionWorkItem: DispatchWorkItem?
        /// Incremented every time recognition is (re)scheduled. A pending
        /// async recognition call checks this against its own captured
        /// value before applying its result — if a newer attempt has been
        /// scheduled since (even one that's itself still awaiting the
        /// recognizer), the older, now-stale result is discarded instead of
        /// being applied on top of a drawing that's moved on. Timer
        /// cancellation alone isn't enough for this: the recognizer call
        /// itself is async and can take long enough for a second attempt to
        /// get scheduled and start before the first one returns.
        var recognitionGeneration = 0
        /// Set while a successful recognition removes source strokes from
        /// canvasView.drawing, for the same re-entrancy reason as
        /// isApplyingSelectionUpdate above.
        var isApplyingRecognitionUpdate = false
        var textViewsByID: [UUID: UITextView] = [:]
        var deleteButtonsByID: [UUID: UIButton] = [:]
        var fontButtonsByID: [UUID: UIButton] = [:]
        var selectedTextObjectID: UUID?
        var editingTextObjectID: UUID?

        init(
            fontSettings: FontSettingsStore,
            recognitionSettings: RecognitionSettingsStore,
            textStore: RecognizedTextStore
        ) {
            self.fontSettings = fontSettings
            self.recognitionSettings = recognitionSettings
            self.textStore = textStore
        }

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
            scheduleRecognition(in: canvasView)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingSelectionUpdate, !isApplyingRecognitionUpdate else { return }
            pendingSnapWorkItem?.cancel()
            pendingRecognitionWorkItem?.cancel()
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
            scheduleRecognition(in: canvasView)
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
                  !snapEvaluatedStrokeIDs.contains(lastStroke.id) else { return }

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

            guard let snap = ShapeSnapService.snap(stroke: lastStroke) else {
                snapEvaluatedStrokeIDs.insert(lastStroke.id)
                return
            }

            snappedStrokeIDs.insert(snap.stroke.id)
            var strokes = canvasView.drawing.strokes
            strokes[strokes.count - 1] = snap.stroke
            canvasView.drawing = PKDrawing(strokes: strokes)

            select(strokeID: snap.stroke.id, fit: snap.fit, originalStroke: lastStroke, in: canvasView)
        }

        private func select(strokeID: UUID, fit: ShapeFit, originalStroke: PKStroke, in canvasView: PKCanvasView) {
            guard let pageContainer else { return }

            selectedStrokeID = strokeID
            selectedFit = fit
            selectedOriginalStroke = originalStroke
            selectedOriginalPoints = Array(originalStroke.path)
            activeCanvasView = canvasView

            let overlay = selectionOverlay ?? makeSelectionOverlay(in: pageContainer)
            overlay.update(boundingBox: fit.boundingBox)
        }

        private func makeSelectionOverlay(in pageContainer: UIView) -> ShapeSelectionOverlayView {
            let overlay = ShapeSelectionOverlayView()
            overlay.onMove = { [weak self] translation in
                self?.applySelectionUpdate { fit in fit.translated(by: translation) }
            }
            overlay.onResize = { [weak self] newCorner in
                self?.applySelectionUpdate { fit in fit.resized(draggingCornerTo: newCorner) }
            }
            overlay.onGestureEnded = { [weak self] in
                self?.dragStartFit = nil
            }
            pageContainer.addSubview(overlay)
            selectionOverlay = overlay
            return overlay
        }

        private func applySelectionUpdate(_ transform: (ShapeFit) -> ShapeFit) {
            guard let baseFit = dragStartFit ?? selectedFit,
                  let canvasView = activeCanvasView,
                  let strokeID = selectedStrokeID,
                  let originalStroke = selectedOriginalStroke,
                  let index = canvasView.drawing.strokes.firstIndex(where: { $0.id == strokeID }) else { return }
            if dragStartFit == nil { dragStartFit = selectedFit }

            let newFit = transform(baseFit)
            let newStroke = ShapeSnapService.buildStroke(
                for: newFit,
                matching: originalStroke,
                originalPoints: selectedOriginalPoints
            )

            isApplyingSelectionUpdate = true
            var strokes = canvasView.drawing.strokes
            strokes[index] = newStroke
            canvasView.drawing = PKDrawing(strokes: strokes)
            isApplyingSelectionUpdate = false

            selectedStrokeID = newStroke.id
            selectedFit = newFit
            selectionOverlay?.update(boundingBox: newFit.boundingBox)
        }

        @objc func handleDeselectTap(_ gesture: UITapGestureRecognizer) {
            guard let pageContainer else { return }
            let location = gesture.location(in: pageContainer)

            if let overlay = selectionOverlay, overlay.frame.insetBy(dx: -8, dy: -8).contains(location) {
                return
            }
            if let selectedTextObjectID, let textView = textViewsByID[selectedTextObjectID],
               textView.frame.insetBy(dx: -8, dy: -8).contains(location) {
                return
            }
            deselect()
            deselectTextObject()
        }

        private func deselect() {
            selectionOverlay?.removeFromSuperview()
            selectionOverlay = nil
            selectedStrokeID = nil
            selectedFit = nil
            selectedOriginalStroke = nil
            selectedOriginalPoints = []
            dragStartFit = nil
        }
    }
}
