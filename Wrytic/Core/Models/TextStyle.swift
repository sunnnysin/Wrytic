import CoreGraphics

struct TextStyle: Codable, Equatable {
    var font: AppFont
    var weight: FontWeight
    var size: CGFloat
    var color: TextColor = .label

    static let `default` = TextStyle(font: .noteworthy, weight: .bold, size: 20, color: .label)
}
