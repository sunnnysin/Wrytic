import Foundation

@Observable
final class RecognizedTextStore {
    private(set) var textObjects: [RecognizedTextObject] = []

    func add(_ object: RecognizedTextObject) {
        textObjects.append(object)
    }

    func update(_ object: RecognizedTextObject) {
        guard let index = textObjects.firstIndex(where: { $0.id == object.id }) else { return }
        textObjects[index] = object
    }

    func remove(id: UUID) {
        textObjects.removeAll { $0.id == id }
    }
}
