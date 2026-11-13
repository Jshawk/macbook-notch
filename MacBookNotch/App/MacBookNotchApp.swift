import SwiftUI

@main
struct MacBookNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(
            "MacBook Notch",
            systemImage: "rectangle.topthird.inset.filled",
            isInserted: Bindable(appDelegate.settings).showMenuBarIcon
        ) {
            Button("Settings…") { appDelegate.showSettings() }
                .keyboardShortcut(",")
            Divider()
            Button("Quit MacBook Notch") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
