import Testing
import PencilKit
@testable import Wrytic

struct StrokeHoldDetectorTests {
    private func makePoint(x: CGFloat, y: CGFloat, timeOffset: TimeInterval) -> PKStrokePoint {
        PKStrokePoint(
            location: CGPoint(x: x, y: y),
            timeOffset: timeOffset,
            size: CGSize(width: 2, height: 2),
            opacity: 1,
            force: 1,
            azimuth: 0,
            altitude: 0
        )
    }

    @Test func detectsHoldWhenTrailingPointsStayStill() {
        var points = (0..<10).map { makePoint(x: CGFloat($0) * 10, y: 0, timeOffset: TimeInterval($0) * 0.05) }
        points += (0..<10).map { makePoint(x: 100, y: 0, timeOffset: 0.5 + TimeInterval($0) * 0.05) }
        #expect(StrokeHoldDetector.isHeldStillAtEnd(points: points) == true)
    }

    @Test func noHoldWhenStrokeKeepsMovingUntilTheEnd() {
        let points = (0..<20).map { makePoint(x: CGFloat($0) * 10, y: 0, timeOffset: TimeInterval($0) * 0.05) }
        #expect(StrokeHoldDetector.isHeldStillAtEnd(points: points) == false)
    }

    @Test func noHoldWhenStrokeIsTooShortInDuration() {
        let points = (0..<3).map { makePoint(x: CGFloat($0), y: 0, timeOffset: TimeInterval($0) * 0.01) }
        #expect(StrokeHoldDetector.isHeldStillAtEnd(points: points) == false)
    }
}
