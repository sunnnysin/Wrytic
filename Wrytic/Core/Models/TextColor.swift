import SwiftUI
import UIKit

/// Stored as RGB components rather than a fixed palette so any color from
/// the system color picker round-trips — a small set of presets are just
/// convenience shortcuts into the same representation.
struct TextColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(uiColor: UIColor) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.red = Double(red)
        self.green = Double(green)
        self.blue = Double(blue)
    }

    init(color: Color) {
        self.init(uiColor: UIColor(color))
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }

    static let label = TextColor(red: 0.11, green: 0.11, blue: 0.12)
    static let blue = TextColor(uiColor: .systemBlue)
    static let red = TextColor(uiColor: .systemRed)
    static let green = TextColor(uiColor: .systemGreen)
    static let purple = TextColor(uiColor: .systemPurple)
    static let orange = TextColor(uiColor: .systemOrange)

    static let presets: [TextColor] = [.label, .blue, .red, .green, .purple, .orange]
}
