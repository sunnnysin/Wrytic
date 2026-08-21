import CoreGraphics

enum ImageGeometry {
    static let minimumSize: CGFloat = 40

    static func translated(_ frame: CGRect, by delta: CGPoint) -> CGRect {
        frame.offsetBy(dx: delta.x, dy: delta.y)
    }

    /// Drags the bottom-right corner to `newCorner`, keeping the top-left
    /// anchored and the original aspect ratio locked — a free-form resize
    /// would distort inserted photos, which a corner-drag handle otherwise
    /// implies is safe to do.
    static func resized(_ frame: CGRect, draggingCornerTo newCorner: CGPoint, aspectRatio: CGFloat) -> CGRect {
        let anchor = CGPoint(x: frame.minX, y: frame.minY)
        var width = max(newCorner.x - anchor.x, minimumSize)
        var height = width / aspectRatio
        if height < minimumSize {
            height = minimumSize
            width = height * aspectRatio
        }
        return CGRect(x: anchor.x, y: anchor.y, width: width, height: height)
    }

    /// The default placement/size for a freshly inserted image: centered
    /// on the visible page area, scaled down to fit a reasonable footprint
    /// if the source image is larger, never scaled up past its own size.
    static func defaultFrame(forImageSize imageSize: CGSize, pageSize: CGSize) -> CGRect {
        let maxDimension: CGFloat = 500
        let scale = min(1, maxDimension / max(imageSize.width, imageSize.height))
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (pageSize.width - size.width) / 2, y: (pageSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }
}
