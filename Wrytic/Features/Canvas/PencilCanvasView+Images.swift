import PencilKit
import UIKit

extension PencilCanvasView.Coordinator {
    /// Inserted below `canvasView` (not above, the way `RecognizedTextView`
    /// sits) so ink drawn with the Pencil composites naturally on top of the
    /// image with no hit-test passthrough needed for drawing — `canvasView`
    /// is already transparent and already the frontmost content layer.
    /// The tradeoff: the image view itself can never receive touches
    /// directly, since `canvasView` sits above it and is hit-tested first.
    /// Selection is resolved by frame-checking in `handleDeselectTap`
    /// instead, and move/resize are handled by `ShapeSelectionOverlayView`,
    /// which — like the image's own selection chrome needs to — sits above
    /// `canvasView` only while an image is actually selected.
    func insertImage(_ image: UIImage) {
        guard let pageContainer, let data = image.pngData() else { return }
        let frame = ImageGeometry.defaultFrame(
            forImageSize: image.size,
            pageSize: PencilCanvasConfiguration.pageSize
        )
        let object = ImageObject(imageData: data, frame: frame)
        imageStore.add(object)
        addImageOverlay(for: object)
        selectImage(id: object.id)
    }

    func addImageOverlay(for object: ImageObject) {
        guard let pageContainer, let canvasView = canvasViewRef,
              let image = UIImage(data: object.imageData) else { return }
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.frame = object.frame
        pageContainer.insertSubview(imageView, belowSubview: canvasView)
        imageViewsByID[object.id] = imageView
    }

    func selectImage(id: UUID) {
        guard let pageContainer,
              let object = imageStore.imageObjects.first(where: { $0.id == id }) else { return }
        if selectedImageID != id {
            deselectImage()
        }
        selectedImageID = id
        let overlay = imageSelectionOverlay ?? makeImageSelectionOverlay(in: pageContainer)
        overlay.update(boundingBox: object.frame)
    }

    func deselectImage() {
        imageSelectionOverlay?.removeFromSuperview()
        imageSelectionOverlay = nil
        selectedImageID = nil
        dragStartImageFrame = nil
    }

    private func makeImageSelectionOverlay(in pageContainer: UIView) -> ShapeSelectionOverlayView {
        let overlay = ShapeSelectionOverlayView()
        overlay.onMove = { [weak self] translation in
            self?.applyImageSelectionUpdate { frame in ImageGeometry.translated(frame, by: translation) }
        }
        overlay.onResize = { [weak self] newCorner in
            self?.applyImageSelectionUpdate { frame in
                let aspectRatio = frame.width / frame.height
                return ImageGeometry.resized(frame, draggingCornerTo: newCorner, aspectRatio: aspectRatio)
            }
        }
        overlay.onGestureEnded = { [weak self] in
            self?.dragStartImageFrame = nil
        }
        pageContainer.addSubview(overlay)
        imageSelectionOverlay = overlay
        return overlay
    }

    private func applyImageSelectionUpdate(_ transform: (CGRect) -> CGRect) {
        guard let id = selectedImageID,
              var object = imageStore.imageObjects.first(where: { $0.id == id }) else { return }
        let baseFrame = dragStartImageFrame ?? object.frame
        if dragStartImageFrame == nil { dragStartImageFrame = object.frame }

        let newFrame = transform(baseFrame)
        object.frame = newFrame
        imageStore.update(object)
        imageViewsByID[id]?.frame = newFrame
        imageSelectionOverlay?.update(boundingBox: newFrame)
    }
}
