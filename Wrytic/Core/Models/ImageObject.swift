import Foundation
import CoreGraphics

struct ImageObject: Identifiable, Equatable {
    let id: UUID
    var imageData: Data
    var frame: CGRect

    init(id: UUID = UUID(), imageData: Data, frame: CGRect) {
        self.id = id
        self.imageData = imageData
        self.frame = frame
    }
}
