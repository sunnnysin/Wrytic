import Testing
import Foundation
@testable import Wrytic

struct SelectionGroupTests {
    @Test func unionSpansEveryMemberRect() {
        let union = SelectionGroup.union(of: [
            CGRect(x: 0, y: 0, width: 10, height: 10),
            CGRect(x: 90, y: 40, width: 10, height: 10),
            CGRect(x: 20, y: 200, width: 5, height: 5)
        ])

        #expect(union == CGRect(x: 0, y: 0, width: 100, height: 205))
    }

    @Test func unionOfNothingIsZero() {
        #expect(SelectionGroup.union(of: []) == .zero)
    }

    @Test func countAndEmptinessCoverEveryItemKind() {
        let empty = SelectionGroup(strokeIDs: [], textObjectIDs: [], imageIDs: [], boundingBox: .zero)
        #expect(empty.isEmpty)
        #expect(empty.count < 1)

        let mixed = SelectionGroup(
            strokeIDs: [UUID(), UUID()],
            textObjectIDs: [UUID()],
            imageIDs: [UUID()],
            boundingBox: .zero
        )
        #expect(!mixed.isEmpty)
        #expect(mixed.count == 4)
    }

    @Test func resizeIsOfferedOnlyForALoneImage() {
        let imageID = UUID()
        let loneImage = SelectionGroup(strokeIDs: [], textObjectIDs: [], imageIDs: [imageID], boundingBox: .zero)
        #expect(loneImage.resizableImageID == imageID)

        let imageWithInk = SelectionGroup(
            strokeIDs: [UUID()],
            textObjectIDs: [],
            imageIDs: [imageID],
            boundingBox: .zero
        )
        #expect(imageWithInk.resizableImageID == nil)

        let twoImages = SelectionGroup(
            strokeIDs: [],
            textObjectIDs: [],
            imageIDs: [UUID(), UUID()],
            boundingBox: .zero
        )
        #expect(twoImages.resizableImageID == nil)
    }
}
