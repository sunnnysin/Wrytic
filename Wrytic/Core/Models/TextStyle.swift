import CoreGraphics

struct TextStyle: Codable, Equatable {
    var font: AppFont
    var weight: FontWeight
    var size: CGFloat

    static let `default` = TextStyle(font: .noteworthy, weight: .bold, size: 20)
}
