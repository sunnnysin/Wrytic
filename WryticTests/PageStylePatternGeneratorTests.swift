import Testing
@testable import Wrytic

struct PageStylePatternGeneratorTests {
    @Test func horizontalLinesAreEvenlySpacedFromMargin() {
        let positions = PageStylePatternGenerator.horizontalLineYPositions(pageHeight: 200)
        #expect(positions.first == PageStylePatternGenerator.margin)
        #expect(positions.allSatisfy { $0 < 200 })
        for index in 1..<positions.count {
            #expect(positions[index] - positions[index - 1] == PageStylePatternGenerator.lineSpacing)
        }
    }

    @Test func noHorizontalLinesWhenPageShorterThanMargin() {
        let positions = PageStylePatternGenerator.horizontalLineYPositions(pageHeight: 10)
        #expect(positions.isEmpty)
    }

    @Test func dotPositionsFillTheGivenPageSize() {
        let size = CGSize(width: 90, height: 60)
        let points = PageStylePatternGenerator.dotPositions(pageSize: size)
        #expect(!points.isEmpty)
        #expect(points.allSatisfy { $0.x < size.width && $0.y < size.height })
    }

    @Test func gridProducesBothHorizontalAndVerticalLines() {
        let xPositions = PageStylePatternGenerator.gridLineXPositions(pageWidth: 200)
        let yPositions = PageStylePatternGenerator.gridLineYPositions(pageHeight: 200)
        #expect(!xPositions.isEmpty)
        #expect(!yPositions.isEmpty)
        #expect(xPositions == yPositions)
    }
}
