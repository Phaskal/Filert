import Foundation

struct WatchedPath: Codable, Identifiable, Equatable {
    let id: UUID
    var path: String
    var isActive: Bool

    var displayName: String {
        (path as NSString).lastPathComponent
    }

    init(id: UUID = UUID(), path: String, isActive: Bool = true) {
        self.id = id
        self.path = path
        self.isActive = isActive
    }
}
