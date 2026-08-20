import SwiftUI
import UIKit

protocol FontAvailabilityService {
    func isAvailable(_ font: AppFont, weight: FontWeight) -> Bool
    func resolvedFont(for font: AppFont, weight: FontWeight, size: CGFloat) -> Font
    func resolvedUIFont(for font: AppFont, weight: FontWeight, size: CGFloat) -> UIFont
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
            guard let name = resolvedPostscriptName(for: font, weight: weight) else { return .system(size: size) }
            return .custom(name, size: size)
        }
    }

    func resolvedUIFont(for font: AppFont, weight: FontWeight, size: CGFloat) -> UIFont {
        switch font {
        case .system:
            return .systemFont(ofSize: size, weight: weight.uiFontWeight)
        case .systemRounded:
            let base = UIFont.systemFont(ofSize: size, weight: weight.uiFontWeight)
            let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        default:
            guard let name = resolvedPostscriptName(for: font, weight: weight),
                  let uiFont = UIFont(name: name, size: size) else {
                return .systemFont(ofSize: size, weight: weight.uiFontWeight)
            }
            return uiFont
        }
    }

    private func resolvedPostscriptName(for font: AppFont, weight: FontWeight) -> String? {
        if let name = font.postscriptName(for: weight), fontExists(name) { return name }
        if weight != .regular, let regularName = font.postscriptName(for: .regular), fontExists(regularName) {
            return regularName
        }
        return nil
    }
}
