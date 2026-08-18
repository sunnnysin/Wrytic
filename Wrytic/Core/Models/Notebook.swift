import Foundation

struct Notebook: Identifiable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date
    var pageStyle: PageStyle

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, pageStyle: PageStyle = .blank) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.pageStyle = pageStyle
    }
}
