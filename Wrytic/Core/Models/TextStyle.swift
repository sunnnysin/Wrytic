import CoreGraphics

struct TextStyle: Codable, Equatable {
    var font: AppFont
    var weight: FontWeight
    var size: CGFloat

    static let `default` = TextStyle(font: .chalkboardSE, weight: .regular, size: 20)
}
