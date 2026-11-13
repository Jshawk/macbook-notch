import Foundation
import Observation
import os

/// Files dropped on the notch, kept until the user removes them.
///
/// Items are references only: removing them or clearing the shelf never touches the files on disk.
/// The app is sandboxed, so access to a dropped file normally ends when the app quits. Each item stores a
/// security-scoped bookmark, which restores access after relaunch and follows the file if it's moved.
@Observable
final class ShelfStore {
    private(set) var items: [ShelfItem] = []

    nonisolated private static let logger = Logger(subsystem: "com.example.MacBookNotch", category: "Shelf")

    @ObservationIgnored private let storageURL: URL?
    /// URLs whose security scope this store opened, so it can close them when items are removed.
    @ObservationIgnored private var accessedURLs: [ShelfItem.ID: URL] = [:]

    /// `Shelf.json` in Application Support, which is inside the app's container.
    static var defaultStorageURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "Shelf.json")
    }

    /// - Parameter storageURL: Where to save the shelf. `nil` keeps it in memory only.
    init(storageURL: URL? = nil) {
        self.storageURL = storageURL
        load()
    }

    /// Pinned items first, then the rest, each in the order they were added.
    var sortedItems: [ShelfItem] {
        items.filter(\.isPinned) + items.filter { !$0.isPinned }
    }

    var hasUnpinnedItems: Bool {
        items.contains { !$0.isPinned }
    }

    /// Adds file URLs, skipping non-file URLs and files already on the shelf.
    /// - Returns: The number of items added.
    @discardableResult
    func add(_ urls: [URL]) -> Int {
        var added = 0
        for url in urls where url.isFileURL {
            let standardized = url.standardizedFileURL
            guard !items.contains(where: { $0.url == standardized }) else { continue }
            let bookmark = try? standardized.bookmarkData(options: .withSecurityScope)
            items.append(ShelfItem(url: standardized, bookmark: bookmark))
            added += 1
        }
        if added > 0 { save() }
        return added
    }

    func remove(_ id: ShelfItem.ID) {
        stopAccessing(id)
        items.removeAll { $0.id == id }
        save()
    }

    /// Removes every item that isn't pinned.
    func clear() {
        for item in items where !item.isPinned {
            stopAccessing(item.id)
        }
        items.removeAll { !$0.isPinned }
        save()
    }

    func setPinned(_ id: ShelfItem.ID, _ isPinned: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned = isPinned
        save()
    }

    /// Whether the file still exists where the shelf last found it.
    func isAvailable(_ item: ShelfItem) -> Bool {
        FileManager.default.fileExists(atPath: item.url.path(percentEncoded: false))
    }

    // MARK: Persistence

    private func load() {
        guard let storageURL, let data = try? Data(contentsOf: storageURL) else { return }
        guard let stored = try? JSONDecoder().decode([ShelfItem].self, from: data) else {
            Self.logger.error("Couldn't read the saved shelf; starting empty")
            return
        }
        items = stored.map(restoreAccess)
        save()
    }

    /// Resolves an item's bookmark, reopens access to the file, and refreshes the bookmark if it went stale.
    private func restoreAccess(_ item: ShelfItem) -> ShelfItem {
        guard let bookmark = item.bookmark else { return item }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutUI],
            bookmarkDataIsStale: &isStale
        ) else {
            // Keep the item so the user sees it's unavailable instead of it silently disappearing.
            return item
        }

        var restored = item
        restored.url = url.standardizedFileURL
        if url.startAccessingSecurityScopedResource() {
            accessedURLs[item.id] = url
        }
        if isStale, let refreshed = try? url.bookmarkData(options: .withSecurityScope) {
            restored.bookmark = refreshed
        }
        return restored
    }

    private func stopAccessing(_ id: ShelfItem.ID) {
        accessedURLs.removeValue(forKey: id)?.stopAccessingSecurityScopedResource()
    }

    private func save() {
        guard let storageURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(items).write(to: storageURL, options: .atomic)
        } catch {
            Self.logger.error("Couldn't save the shelf: \(error.localizedDescription, privacy: .public)")
        }
    }
}
