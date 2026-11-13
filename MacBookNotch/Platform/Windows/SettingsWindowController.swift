import AppKit
import SwiftUI

/// Shows a single settings window. The app has no Dock icon, so it activates itself before showing it.
final class SettingsWindowController {
    private var window: NSWindow?
    private let makeRootView: () -> AnyView

    init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        makeRootView = { AnyView(content()) }
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: makeRootView()))
        window.title = "MacBook Notch Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
