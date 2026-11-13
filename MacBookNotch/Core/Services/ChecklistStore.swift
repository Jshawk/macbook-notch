import Foundation
import Observation

/// A short list of tasks for today, kept in the notch and persisted so it survives relaunch.
///
/// Checked-off tasks stay visible for the rest of the day and are cleared on the next one. Unfinished tasks carry over.
@Observable
final class ChecklistStore {
    /// The notch has room for this many rows, so the list stays short enough to see at a glance.
    static let maximumItems = 5

    private(set) var items: [ChecklistItem]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey: String
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "checklist",
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.now = now
        self.calendar = calendar
        items = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([ChecklistItem].self, from: $0) } ?? []
        clearTasksFinishedBeforeToday()
    }

    var canAdd: Bool {
        items.count < Self.maximumItems
    }

    var completedCount: Int {
        items.filter(\.isDone).count
    }

    /// Adds a task to the end of the list.
    /// - Returns: `false` if the title is blank or the list is full.
    @discardableResult
    func add(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canAdd else { return false }
        items.append(ChecklistItem(title: trimmed))
        save()
        return true
    }

    func toggle(_ id: ChecklistItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].completedAt = items[index].isDone ? nil : now()
        save()
    }

    func remove(_ id: ChecklistItem.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    /// Removes tasks checked off on an earlier day. Call when the list is shown, since the day may have changed.
    func clearTasksFinishedBeforeToday() {
        let startOfToday = calendar.startOfDay(for: now())
        let remaining = items.filter { ($0.completedAt ?? .distantFuture) >= startOfToday }
        guard remaining != items else { return }
        items = remaining
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
