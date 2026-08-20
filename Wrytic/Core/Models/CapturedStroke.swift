import Foundation
import CoreGraphics

struct CapturedStroke: Identifiable, Equatable {
    let id: UUID
    let tool: StrokeTool
    let points: [CGPoint]
    let boundingBox: CGRect
    let createdAt: Date
}
