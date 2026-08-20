enum AppFont: String, CaseIterable, Codable, Identifiable, Hashable {
    case chalkboardSE
    case noteworthy
    case helvetica
    case avenir
    case georgia
    case timesNewRoman
    case courier
    case system
    case systemRounded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chalkboardSE: "Chalkboard SE"
        case .noteworthy: "Noteworthy"
        case .helvetica: "Helvetica"
        case .avenir: "Avenir"
        case .georgia: "Georgia"
        case .timesNewRoman: "Times New Roman"
        case .courier: "Courier"
        case .system: "System"
        case .systemRounded: "System Rounded"
        }
    }

    /// PostScript name for the given weight, or `nil` if this family doesn't
    /// ship that weight (e.g. Georgia has no Light) — verified against the
    /// real SDK via `UIFont.fontNames(forFamilyName:)`, not assumed.
    func postscriptName(for weight: FontWeight) -> String? {
        Self.postscriptNamesByWeight[self]?[weight]
    }

    private static let postscriptNamesByWeight: [AppFont: [FontWeight: String]] = [
        .chalkboardSE: [
            .light: "ChalkboardSE-Light",
            .regular: "ChalkboardSE-Regular",
            .bold: "ChalkboardSE-Bold"
        ],
        .noteworthy: [
            .light: "Noteworthy-Light",
            .bold: "Noteworthy-Bold"
        ],
        .helvetica: [
            .light: "Helvetica-Light",
            .regular: "Helvetica",
            .bold: "Helvetica-Bold"
        ],
        .avenir: [
            .light: "Avenir-Light",
            .regular: "Avenir-Book",
            .bold: "Avenir-Heavy"
        ],
        .georgia: [
            .regular: "Georgia",
            .bold: "Georgia-Bold"
        ],
        .timesNewRoman: [
            .regular: "TimesNewRomanPSMT",
            .bold: "TimesNewRomanPS-BoldMT"
        ],
        .courier: [
            .regular: "Courier",
            .bold: "Courier-Bold"
        ]
    ]
}
