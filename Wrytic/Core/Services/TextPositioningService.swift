import CoreGraphics

struct RecognizedTextPlacement: Equatable {
    var style: TextStyle
    var boundingBox: CGRect
}

protocol TextPositioningService: Sendable {
    func position(for group: StrokeGroup, baseStyle: TextStyle) -> RecognizedTextPlacement
}

/// Rendered text always uses the user's configured font size regardless
/// of how large or small the source handwriting was — auto-scaling to
/// match stroke height was tried and rejected: it made the same setting
/// produce visibly different text sizes depending on handwriting size,
/// which reads as inconsistent rather than as "positioning." Only the
/// placement adapts: the label is anchored by vertical center on the
/// source strokes' bounding box, rather than by raw top, so ascenders/
/// descenders in the handwriting (which extend past a glyph's own visual
/// center) don't drift the rendered line up relative to where it was
/// actually written.
struct HandwritingTextPositioningService: TextPositioningService {
    var labelHeightMultiplier: CGFloat = 1.25

    func position(for group: StrokeGroup, baseStyle: TextStyle) -> RecognizedTextPlacement {
        let bbox = group.boundingBox
        guard bbox.height > 0 else {
            return RecognizedTextPlacement(style: baseStyle, boundingBox: bbox)
        }

        let height = ceil(baseStyle.size * labelHeightMultiplier)
        let originY = bbox.midY - height / 2

        let boundingBox = CGRect(x: bbox.minX, y: originY, width: bbox.width, height: height)
        return RecognizedTextPlacement(style: baseStyle, boundingBox: boundingBox)
    }
}
