import Testing
import Foundation
@testable import Wrytic

struct LassoHitTestingTests {
    private let loop = [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 200, y: 0),
        CGPoint(x: 200, y: 200),
        CGPoint(x: 0, y: 200)
    ]

    @Test func enclosedRectIsSelected() {
        let candidate = LassoHitTesting.Candidate(
            id: UUID(),
            samplePoints: LassoHitTesting.sampleRect(CGRect(x: 40, y: 40, width: 60, height: 60))
        )

        #expect(LassoHitTesting.selected(within: loop, from: [candidate]) == [candidate.id])
    }

    @Test func rectThatMerelyGrazesTheLoopIsNotSelected() {
        let candidate = LassoHitTesting.Candidate(
            id: UUID(),
            samplePoints: LassoHitTesting.sampleRect(CGRect(x: 170, y: 170, width: 200, height: 200))
        )

        #expect(LassoHitTesting.selected(within: loop, from: [candidate]).isEmpty)
    }

    @Test func strokeMostlyInsideTheLoopIsSelected() {
        let points = (0...10).map { CGPoint(x: 20 + $0 * 10, y: 100) }
        let candidate = LassoHitTesting.Candidate(id: UUID(), samplePoints: points)

        #expect(LassoHitTesting.selected(within: loop, from: [candidate]) == [candidate.id])
    }

    @Test func strokeMostlyOutsideTheLoopIsNotSelected() {
        let points = (0...10).map { CGPoint(x: 150 + $0 * 20, y: 100) }
        let candidate = LassoHitTesting.Candidate(id: UUID(), samplePoints: points)

        #expect(LassoHitTesting.selected(within: loop, from: [candidate]).isEmpty)
    }

    @Test func aDegenerateLoopSelectsNothing() {
        let candidate = LassoHitTesting.Candidate(
            id: UUID(),
            samplePoints: LassoHitTesting.sampleRect(CGRect(x: 10, y: 10, width: 10, height: 10))
        )

        #expect(LassoHitTesting.selected(within: [CGPoint(x: 5, y: 5), CGPoint(x: 6, y: 6)], from: [candidate]).isEmpty)
    }

    @Test func selectionSpansEveryEnclosedCandidateIndependently() {
        let inside = LassoHitTesting.Candidate(
            id: UUID(),
            samplePoints: LassoHitTesting.sampleRect(CGRect(x: 20, y: 20, width: 40, height: 40))
        )
        let outside = LassoHitTesting.Candidate(
            id: UUID(),
            samplePoints: LassoHitTesting.sampleRect(CGRect(x: 400, y: 400, width: 40, height: 40))
        )

        #expect(LassoHitTesting.selected(within: loop, from: [inside, outside]) == [inside.id])
    }
}
