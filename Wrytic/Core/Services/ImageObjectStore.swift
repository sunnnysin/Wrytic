import Foundation

@Observable
final class ImageObjectStore {
    private(set) var imageObjects: [ImageObject] = []

    func add(_ object: ImageObject) {
        imageObjects.append(object)
    }

    func update(_ object: ImageObject) {
        guard let index = imageObjects.firstIndex(where: { $0.id == object.id }) else { return }
        imageObjects[index] = object
    }

    func remove(id: UUID) {
        imageObjects.removeAll { $0.id == id }
    }
}
