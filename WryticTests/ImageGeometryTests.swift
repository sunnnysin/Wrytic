import Testing
import Foundation
@testable import Wrytic

struct ImageGeometryTests {
    @Test func translatedOffsetsTheFrame() {
        let frame = CGRect(x: 10, y: 20, width: 100, height: 50)

        let result = ImageGeometry.translated(frame, by: CGPoint(x: 5, y: -8))

        #expect(result == CGRect(x: 15, y: 12, width: 100, height: 50))
    }

    @Test func resizedKeepsAspectRatioWhenDraggingCorner() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 50)

        let result = ImageGeometry.resized(frame, draggingCornerTo: CGPoint(x: 200, y: 999), aspectRatio: 2)

        #expect(result.origin == .zero)
        #expect(result.width == 200)
        #expect(result.height == 100)
    }

    @Test func resizedClampsToMinimumSize() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        let result = ImageGeometry.resized(frame, draggingCornerTo: CGPoint(x: 2, y: 2), aspectRatio: 1)

        #expect(result.width >= ImageGeometry.minimumSize)
        #expect(result.height >= ImageGeometry.minimumSize)
    }

    /// A tall/narrow image (aspectRatio < 1) dragged to a corner narrower
    /// than `minimumSize` clamps width up to `minimumSize` first — for this
    /// aspect ratio that alone already yields a height comfortably above
    /// `minimumSize`, so the height-side clamp never needs to kick in.
    @Test func resizedClampsWidthFirstForTallAspectRatio() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 400)

        let result = ImageGeometry.resized(frame, draggingCornerTo: CGPoint(x: 20, y: 999), aspectRatio: 0.25)

        #expect(result.width == ImageGeometry.minimumSize)
        #expect(result.height == ImageGeometry.minimumSize / 0.25)
    }

    /// A wide/short image (aspectRatio > 1) dragged to a corner narrower
    /// than `minimumSize` clamps width up first, same as any aspect ratio —
    /// but here that alone still leaves height under `minimumSize`, so the
    /// height-side clamp (and the width recompute that follows it) is what
    /// actually determines the final size.
    @Test func resizedClampsHeightForWideAspectRatio() {
        let frame = CGRect(x: 0, y: 0, width: 400, height: 100)

        let result = ImageGeometry.resized(frame, draggingCornerTo: CGPoint(x: 5, y: 999), aspectRatio: 4)

        #expect(result.height == ImageGeometry.minimumSize)
        #expect(result.width == ImageGeometry.minimumSize * 4)
    }

    @Test func defaultFrameCentersAndScalesDownLargeImages() {
        let pageSize = CGSize(width: 1600, height: 2200)

        let frame = ImageGeometry.defaultFrame(forImageSize: CGSize(width: 2000, height: 1000), pageSize: pageSize)

        #expect(frame.width == 500)
        #expect(frame.height == 250)
        #expect(frame.midX == pageSize.width / 2)
        #expect(frame.midY == pageSize.height / 2)
    }

    @Test func defaultFrameNeverScalesUpASmallImage() {
        let pageSize = CGSize(width: 1600, height: 2200)

        let frame = ImageGeometry.defaultFrame(forImageSize: CGSize(width: 80, height: 40), pageSize: pageSize)

        #expect(frame.width == 80)
        #expect(frame.height == 40)
    }
}
