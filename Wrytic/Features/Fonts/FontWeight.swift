import SwiftUI

enum FontWeight: String, CaseIterable, Codable, Identifiable, Hashable {
    case light
    case regular
    case bold

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var swiftUIWeight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .bold: .bold
        }
    }
}
