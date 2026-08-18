enum PageStyle: String, CaseIterable, Codable, Identifiable {
    case blank
    case lined
    case dotted
    case grid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blank: "Blank"
        case .lined: "Lined"
        case .dotted: "Dotted"
        case .grid: "Grid"
        }
    }
}
