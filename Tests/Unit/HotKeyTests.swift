import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import MacBookNotch

struct HotKeyTests {
    @Test func requiresCommandOptionOrControl() {
        #expect(HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.command], keyLabel: "N").isValid)
        #expect(HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.control, .shift], keyLabel: "N").isValid)
        #expect(!HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.shift], keyLabel: "N").isValid)
        #expect(!HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [], keyLabel: "N").isValid)
    }

    @Test func dropsUnsupportedModifiers() {
        let hotKey = HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.command, .capsLock, .function], keyLabel: "N")

        #expect(hotKey.modifiers == [.command])
    }

    @Test func convertsToCarbonModifiers() {
        let hotKey = HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.command, .option, .control, .shift], keyLabel: "N")

        #expect(hotKey.carbonModifiers == UInt32(cmdKey | optionKey | controlKey | shiftKey))
    }

    @Test func displaysModifiersInStandardOrder() {
        let hotKey = HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.command, .shift, .option, .control], keyLabel: "N")

        #expect(hotKey.displayString == "⌃⌥⇧⌘N")
    }

    @Test func namesSpecialKeys() {
        #expect(HotKey.keyLabel(keyCode: UInt16(kVK_Space), characters: " ") == "Space")
        #expect(HotKey.keyLabel(keyCode: UInt16(kVK_F5), characters: nil) == "F5")
        #expect(HotKey.keyLabel(keyCode: UInt16(kVK_ANSI_K), characters: "k") == "K")
    }

    @Test func roundTripsThroughCodable() throws {
        let hotKey = HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.command, .option], keyLabel: "N")

        let decoded = try JSONDecoder().decode(HotKey.self, from: JSONEncoder().encode(hotKey))

        #expect(decoded == hotKey)
    }
}
