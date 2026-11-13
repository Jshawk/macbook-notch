import AppKit
import Quartz

/// Supplies files to the shared Quick Look panel.
///
/// Quick Look asks the key window's responder chain who controls the panel; `NotchPanel` answers and hands over
/// this presenter. The app activates so the preview can take keyboard focus, and the previously active app is
/// reactivated when the preview closes.
final class QuickLookPresenter: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var urls: [URL] = []
    private var previousApp: NSRunningApplication?
    private var onClose: (() -> Void)?

    func show(_ urls: [URL], from panel: NSPanel, onClose: @escaping () -> Void) {
        self.urls = urls
        self.onClose = onClose

        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = frontmost
        }
        NSApp.activate()
        panel.makeKey()

        guard let preview = QLPreviewPanel.shared() else { return }
        if preview.isVisible {
            preview.reloadData()
        } else {
            preview.makeKeyAndOrderFront(nil)
        }
    }

    /// Called by `NotchPanel` when Quick Look stops using this presenter.
    func didClose() {
        onClose?()
        onClose = nil
        previousApp?.activate()
        previousApp = nil
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        urls[index] as NSURL
    }
}
