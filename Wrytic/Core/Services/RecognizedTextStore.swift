import Foundation

@Observable
final class RecognizedTextStore {
    private(set) var textObjects: [RecognizedTextObject] = []

    func add(_ object: RecognizedTextObject) {
        textObjects.append(object)
    }
}
