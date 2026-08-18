import CoreGraphics

enum PageStylePatternGenerator {
    static let lineSpacing: CGFloat = 40
    static let dotSpacing: CGFloat = 30
    static let gridSpacing: CGFloat = 40
    static let margin: CGFloat = 20

    static func horizontalLineYPositions(pageHeight: CGFloat) -> [CGFloat] {
        guard pageHeight > margin else { return [] }
        return Array(stride(from: margin, to: pageHeight, by: lineSpacing))
    }

    static func dotPositions(pageSize: CGSize) -> [CGPoint] {
        guard pageSize.width > 0, pageSize.height > 0 else { return [] }
        var points: [CGPoint] = []
        for y in stride(from: dotSpacing, to: pageSize.height, by: dotSpacing) {
            for x in stride(from: dotSpacing, to: pageSize.width, by: dotSpacing) {
                points.append(CGPoint(x: x, y: y))
            }
        }
        return points
    }

    static func gridLineXPositions(pageWidth: CGFloat) -> [CGFloat] {
        guard pageWidth > 0 else { return [] }
        return Array(stride(from: gridSpacing, to: pageWidth, by: gridSpacing))
    }

    static func gridLineYPositions(pageHeight: CGFloat) -> [CGFloat] {
        guard pageHeight > 0 else { return [] }
        return Array(stride(from: gridSpacing, to: pageHeight, by: gridSpacing))
    }
}
