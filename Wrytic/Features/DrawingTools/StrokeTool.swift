import PencilKit

enum StrokeTool: String, CaseIterable, Codable {
    case pen
    case highlighter
    case shape

    static func from(_ stroke: PKStroke, isShapeSnapped: Bool = false) -> StrokeTool {
        guard !isShapeSnapped else { return .shape }
        switch stroke.ink.inkType {
        case .marker:
            return .highlighter
        default:
            return .pen
        }
    }
}
