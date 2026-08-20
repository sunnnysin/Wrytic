import Testing
import Foundation
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

    @Test func roughRectangleStrokeGetsSnapped() {
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

        let stroke = makeStroke(points: points)
        let snapped = ShapeSnapService.snap(stroke: stroke)

        #expect(snapped != nil)
        #expect(snapped?.stroke.ink.inkType == .pen)
        #expect(snapped?.fit == .rectangle(CGRect(x: 0, y: 0, width: 120, height: 80)))
    }

    @Test func zigzagScribbleIsNotSnapped() {
        let offsets: [CGFloat] = [0, 20, -10, 15, -5, 20, 0, 15, -10, 20]
        let points = offsets.enumerated().map { index, yOffset in
            makePoint(x: CGFloat(index) * 10, y: yOffset, timeOffset: TimeInterval(index) * 0.03)
        }
        let stroke = makeStroke(points: points)
        #expect(ShapeSnapService.snap(stroke: stroke) == nil)
    }
}
