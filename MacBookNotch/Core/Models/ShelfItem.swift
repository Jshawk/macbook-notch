import Foundation

/// A reference to a file dropped on the notch. The shelf never copies, moves, or deletes the file itself.
nonisolated struct ShelfItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    /// Where the file was when last seen. Updated when its bookmark resolves to a new location.
    var url: URL
    let addedAt: Date
    /// Pinned items stay when the shelf is cleared and appear first.
    var isPinned: Bool
    /// A security-scoped bookmark that lets the sandboxed app open the file again after relaunch.
    var bookmark: Data?

    init(id: UUID = UUID(), url: URL, addedAt: Date = .now, isPinned: Bool = false, bookmark: Data? = nil) {
        self.id = id
        self.url = url
        self.addedAt = addedAt
        self.isPinned = isPinned
        self.bookmark = bookmark
    }

    var name: String {
        url.lastPathComponent
    }
}
