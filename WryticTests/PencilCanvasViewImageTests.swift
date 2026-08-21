import Testing
import UIKit
import PencilKit
@testable import Wrytic

@MainActor
struct PencilCanvasViewImageTests {
    private func makeCoordinator() -> (coordinator: PencilCanvasView.Coordinator, pageContainer: UIView) {
        let coordinator = PencilCanvasView.Coordinator(
            fontSettings: FontSettingsStore(),
            recognitionSettings: RecognitionSettingsStore(),
            textStore: RecognizedTextStore(),
            imageStore: ImageObjectStore()
        )
        let pageContainer = UIView(frame: CGRect(origin: .zero, size: PencilCanvasConfiguration.pageSize))
        let canvasView = PKCanvasView(frame: pageContainer.bounds)
        pageContainer.addSubview(canvasView)
        coordinator.pageContainer = pageContainer
        coordinator.canvasViewRef = canvasView
        return (coordinator, pageContainer)
    }

    private func makeImage(width: CGFloat = 40, height: CGFloat = 20) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func insertImageAddsToStoreAndSelectsIt() {
        let (coordinator, pageContainer) = makeCoordinator()

        coordinator.insertImage(makeImage())

        #expect(coordinator.imageStore.imageObjects.count == 1)
        #expect(coordinator.selectedImageID == coordinator.imageStore.imageObjects.first?.id)
        if let imageView = coordinator.imageViewsByID.values.first {
            #expect(pageContainer.subviews.contains(imageView))
        } else {
            Issue.record("expected an image view added to pageContainer")
        }
    }

    /// The image view must sit below canvasView in `pageContainer` so ink
    /// drawn with the Pencil composites visually on top of the image — see
    /// PencilCanvasView+Images.swift for why this ordering (rather than a
    /// hit-test passthrough, the trick used for converted text) is what
    /// actually makes "write on top of an inserted image" work.
    @Test func insertImagePlacesTheImageViewBelowTheCanvas() {
        let (coordinator, pageContainer) = makeCoordinator()

        coordinator.insertImage(makeImage())

        guard let imageView = coordinator.imageViewsByID.values.first,
              let canvasView = coordinator.canvasViewRef,
              let imageIndex = pageContainer.subviews.firstIndex(of: imageView),
              let canvasIndex = pageContainer.subviews.firstIndex(of: canvasView) else {
            Issue.record("expected an image view inserted into pageContainer below canvasView")
            return
        }
        #expect(imageIndex < canvasIndex)
    }

    @Test func movingTheSelectionOverlayUpdatesTheStoredFrame() {
        let (coordinator, pageContainer) = makeCoordinator()
        coordinator.insertImage(makeImage())
        guard let id = coordinator.imageStore.imageObjects.first?.id,
              let originalFrame = coordinator.imageStore.imageObjects.first?.frame else {
            Issue.record("expected an inserted, selected image")
            return
        }

        coordinator.imageSelectionOverlay?.onMove?(CGPoint(x: 15, y: -6))
        coordinator.imageSelectionOverlay?.onGestureEnded?()

        let updated = coordinator.imageStore.imageObjects.first { $0.id == id }
        #expect(updated?.frame.origin == CGPoint(x: originalFrame.minX + 15, y: originalFrame.minY - 6))
        #expect(coordinator.imageViewsByID[id]?.frame == updated?.frame)
        if let overlay = coordinator.imageSelectionOverlay {
            #expect(pageContainer.subviews.contains(overlay))
        }
    }

    @Test func resizingTheSelectionOverlayKeepsAspectRatioAndUpdatesTheView() {
        let (coordinator, pageContainer) = makeCoordinator()
        coordinator.insertImage(makeImage(width: 100, height: 50))
        guard let id = coordinator.imageStore.imageObjects.first?.id,
              let originalFrame = coordinator.imageStore.imageObjects.first?.frame else {
            Issue.record("expected an inserted, selected image")
            return
        }

        let newCorner = CGPoint(x: originalFrame.minX + 400, y: originalFrame.minY + 999)
        coordinator.imageSelectionOverlay?.onResize?(newCorner)
        coordinator.imageSelectionOverlay?.onGestureEnded?()

        let updated = coordinator.imageStore.imageObjects.first { $0.id == id }
        #expect(updated?.frame.width == 400)
        #expect(updated?.frame.height == 200)
        #expect(coordinator.imageViewsByID[id]?.frame == updated?.frame)
        if let imageView = coordinator.imageViewsByID[id] {
            #expect(pageContainer.subviews.contains(imageView))
        }
    }

    @Test func deselectImageRemovesTheOverlay() {
        let (coordinator, pageContainer) = makeCoordinator()
        coordinator.insertImage(makeImage())
        guard let overlay = coordinator.imageSelectionOverlay else {
            Issue.record("expected a selection overlay after inserting an image")
            return
        }
        #expect(pageContainer.subviews.contains(overlay))

        coordinator.deselectImage()

        #expect(coordinator.imageSelectionOverlay == nil)
        #expect(coordinator.selectedImageID == nil)
        #expect(!pageContainer.subviews.contains(overlay))
    }
}
