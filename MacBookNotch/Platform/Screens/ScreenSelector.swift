import AppKit

/// Chooses which screen hosts the notch panel.
enum ScreenSelector {
    static func screen(for preference: DisplayPreference, among screens: [NSScreen] = NSScreen.screens) -> NSScreen? {
        // The first screen in the list is the one that owns the menu bar.
        let primary = screens.first

        switch preference {
        case .builtIn:
            return screens.first(where: \.hasNotch)
                ?? screens.first(where: \.isBuiltIn)
                ?? primary
        case .primary:
            return primary
        }
    }
}
