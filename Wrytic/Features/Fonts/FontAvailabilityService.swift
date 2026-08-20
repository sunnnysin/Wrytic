import SwiftUI
import UIKit

protocol FontAvailabilityService {
    func isAvailable(_ font: AppFont, weight: FontWeight) -> Bool
    func resolvedFont(for font: AppFont, weight: FontWeight, size: CGFloat) -> Font
}

struct SystemFontAvailabilityService: FontAvailabilityService {
    var fontExists: (String) -> Bool = { UIFont(name: $0, size: UIFont.systemFontSize) != nil }

    func isAvailable(_ font: AppFont, weight: FontWeight) -> Bool {
        switch font {
        case .system, .systemRounded:
            return true
        default:
            guard let postscriptName = font.postscriptName(for: weight) else { return false }
            return fontExists(postscriptName)
        }
    }

    func resolvedFont(for font: AppFont, weight: FontWeight, size: CGFloat) -> Font {
        switch font {
        case .system:
            return .system(size: size, weight: weight.swiftUIWeight)
        case .systemRounded:
            return .system(size: size, weight: weight.swiftUIWeight, design: .rounded)
        default:
            if let name = font.postscriptName(for: weight), fontExists(name) {
                return .custom(name, size: size)
            }
            if weight != .regular, let regularName = font.postscriptName(for: .regular), fontExists(regularName) {
                return .custom(regularName, size: size)
            }
            return .system(size: size)
        }
    }
}
