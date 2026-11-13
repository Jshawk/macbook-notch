import AppKit
import SwiftUI

/// Hosts SwiftUI content in the notch panel and reports pointer movement while the panel receives mouse events.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var onPointerEvent: (() -> Void)?

    private var trackingArea: NSTrackingArea?

    required init(rootView: Content) {
        super.init(rootView: rootView)
        // The panel's size is controlled by the window controller, not by the SwiftUI content.
        sizingOptions = []
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lets the first click act on content even though the panel never becomes key.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onPointerEvent?()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onPointerEvent?()
    }
}
