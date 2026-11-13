import Foundation

/// A task on today's checklist.
nonisolated struct ChecklistItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
    /// When the task was checked off. `nil` while it's still to do.
    var completedAt: Date?

    init(id: UUID = UUID(), title: String, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.completedAt = completedAt
    }

    var isDone: Bool {
        completedAt != nil
    }
}
