import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut.
nonisolated struct HotKey: Codable, Equatable, Sendable {
    /// Virtual key code, as reported by `NSEvent.keyCode`.
    var keyCode: UInt16
    /// Raw value of the device-independent `NSEvent.ModifierFlags`.
    var modifierFlags: UInt
    /// The key's label captured when the shortcut was recorded, such as "N" or "Space".
    var keyLabel: String

    static let supportedModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, keyLabel: String) {
        self.keyCode = keyCode
        modifierFlags = modifiers.intersection(Self.supportedModifiers).rawValue
        self.keyLabel = keyLabel
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
    }

    /// A global shortcut needs ⌘, ⌥, or ⌃ so it doesn't swallow ordinary typing.
    var isValid: Bool {
        !modifiers.intersection([.command, .option, .control]).isEmpty
    }

    var carbonModifiers: UInt32 {
        var result = 0
        if modifiers.contains(.command) { result |= cmdKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.control) { result |= controlKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        return UInt32(result)
    }

    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + keyLabel
    }

    private static let functionKeyCodes = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    /// A readable name for a key event, preferring names for keys that don't produce visible characters.
    static func keyLabel(keyCode: UInt16, characters: String?) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            // Function key codes aren't in numeric order, so look them up rather than using a range.
            if let index = functionKeyCodes.firstIndex(of: Int(keyCode)) {
                return "F\(index + 1)"
            }
        }
        let trimmed = characters?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Key \(keyCode)" : trimmed.uppercased()
    }
}
