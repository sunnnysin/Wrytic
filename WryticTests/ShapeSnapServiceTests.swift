import Testing
import PencilKit
@testable import Wrytic

struct ShapeSnapServiceTests {
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

    private func makeStroke(points: [PKStrokePoint], inkType: PKInkingTool.InkType = .pen) -> PKStroke {
        let path = PKStrokePath(controlPoints: points, creationDate: .now)
        let ink = PKInk(inkType, color: .black)
        return PKStroke(ink: ink, path: path)
    }

    @Test func heldRectangleGetsSnapped() {
        let rect = CGRect(x: 0, y: 0, width: 120, height: 80)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.minY)
        ]
        var points: [PKStrokePoint] = []
        var time: TimeInterval = 0
        for index in 0..<(corners.count - 1) {
            for step in 0..<10 {
                let fraction = CGFloat(step) / 10
                let start = corners[index]
                let end = corners[index + 1]
                let location = CGPoint(
                    x: start.x + (end.x - start.x) * fraction,
                    y: start.y + (end.y - start.y) * fraction
                )
                points.append(makePoint(x: location.x, y: location.y, timeOffset: time))
                time += 0.02
            }
        }
        for _ in 0..<10 {
            points.append(makePoint(x: corners[0].x, y: corners[0].y, timeOffset: time))
            time += 0.05
        }

        let stroke = makeStroke(points: points)
        let snapped = ShapeSnapService.snappedStroke(for: stroke)

        #expect(snapped != nil)
        #expect(snapped?.ink.inkType == .pen)
    }

    @Test func ordinaryHandwritingStrokeIsNotSnapped() {
        let points = (0..<30).map {
            makePoint(x: CGFloat($0) * 3, y: CGFloat.random(in: -5...5), timeOffset: TimeInterval($0) * 0.03)
        }
        let stroke = makeStroke(points: points)
        #expect(ShapeSnapService.snappedStroke(for: stroke) == nil)
    }
}
