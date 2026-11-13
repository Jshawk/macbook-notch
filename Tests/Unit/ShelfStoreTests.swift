import Foundation
import Testing
@testable import MacBookNotch

@MainActor
struct ShelfStoreTests {
    private let directory: URL
    private let storageURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "ShelfStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storageURL = directory.appending(path: "Saved/Shelf.json")
    }

    private func makeFile(_ name: String) throws -> URL {
        let url = directory.appending(path: name)
        try Data("test".utf8).write(to: url)
        return url
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    @Test func addsFilesOnceAndSkipsNonFileURLs() throws {
        let store = ShelfStore()
        let file = try makeFile("a.txt")

        let added = store.add([file, file, URL(string: "https://example.com")!])
        let addedAgain = store.add([file])

        #expect(added == 1)
        #expect(addedAgain == 0)
        #expect(store.items.map(\.name) == ["a.txt"])
    }

    @Test func removingAndClearingNeverDeletesFiles() throws {
        let store = ShelfStore(storageURL: storageURL)
        let first = try makeFile("first.txt")
        let second = try makeFile("second.txt")
        store.add([first, second])

        store.remove(try #require(store.items.first).id)
        store.clear()

        #expect(store.items.isEmpty)
        #expect(exists(first))
        #expect(exists(second))
    }

    @Test func marksMovedFilesUnavailable() throws {
        let store = ShelfStore()
        let file = try makeFile("moving.txt")
        store.add([file])
        let item = try #require(store.items.first)
        #expect(store.isAvailable(item))

        try FileManager.default.moveItem(at: file, to: directory.appending(path: "moved.txt"))

        #expect(!store.isAvailable(item))
    }

    @Test func itemsSurviveRelaunch() throws {
        let store = ShelfStore(storageURL: storageURL)
        store.add([try makeFile("report.pdf"), try makeFile("notes.txt")])
        store.setPinned(try #require(store.items.last).id, true)

        let relaunched = ShelfStore(storageURL: storageURL)

        #expect(relaunched.items.map(\.name) == ["report.pdf", "notes.txt"])
        #expect(relaunched.items.map(\.isPinned) == [false, true])
        #expect(relaunched.items.allSatisfy(relaunched.isAvailable))
    }

    @Test func bookmarkFollowsMovedFileAfterRelaunch() throws {
        let store = ShelfStore(storageURL: storageURL)
        let file = try makeFile("draft.txt")
        store.add([file])
        #expect(store.items.first?.bookmark != nil, "Needs the bookmarks entitlement")

        let moved = directory.appending(path: "final.txt")
        try FileManager.default.moveItem(at: file, to: moved)
        let relaunched = ShelfStore(storageURL: storageURL)

        let item = try #require(relaunched.items.first)
        #expect(item.name == "final.txt")
        #expect(relaunched.isAvailable(item))
    }

    @Test func clearKeepsPinnedItemsFirst() throws {
        let store = ShelfStore()
        store.add([try makeFile("a.txt"), try makeFile("b.txt"), try makeFile("c.txt")])
        store.setPinned(store.items[2].id, true)
        #expect(store.sortedItems.map(\.name) == ["c.txt", "a.txt", "b.txt"])

        store.clear()

        #expect(store.items.map(\.name) == ["c.txt"])
        #expect(!store.hasUnpinnedItems)
    }

    @Test func unreadableSaveStartsEmpty() throws {
        try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: storageURL)

        #expect(ShelfStore(storageURL: storageURL).items.isEmpty)
    }
}
