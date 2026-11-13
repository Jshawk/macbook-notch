import AppKit
import Quartz

/// A transparent, borderless panel that floats above the menu bar on every Space.
///
/// The panel becomes key only when needed — a text field is clicked, or the keyboard shortcut opens it —
/// so clicking its buttons doesn't take keyboard focus away from the app the user is working in.
final class NotchPanel: NSPanel {
    /// Called when the user presses Escape while the panel is key.
    var onCancel: (() -> Void)?
    /// Supplies Quick Look previews of shelf items.
    var quickLookPresenter: QuickLookPresenter?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    // Quick Look finds its controller by asking the key window's responder chain. AppKit declares these
    // hooks without actor isolation, but Quick Look calls them on the main thread.

    nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        MainActor.assumeIsolated { quickLookPresenter != nil }
    }

    nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = quickLookPresenter
            panel.delegate = quickLookPresenter
        }
    }

    nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = nil
            panel.delegate = nil
            quickLookPresenter?.didClose()
        }
    }

    /// AppKit normally keeps windows below the menu bar; the notch panel has to sit on top of it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
