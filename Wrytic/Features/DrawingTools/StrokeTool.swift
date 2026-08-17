import PencilKit

enum StrokeTool: String, CaseIterable, Codable {
    case pen
    case highlighter

    static func from(_ stroke: PKStroke) -> StrokeTool {
        switch stroke.ink.inkType {
        case .marker:
            .highlighter
        default:
            .pen
        }
    }
}
