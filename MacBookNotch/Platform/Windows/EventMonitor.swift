import AppKit

/// Observes mouse events delivered both to other apps and to this app.
///
/// Monitoring mouse events globally does not require Accessibility permission.
final class EventMonitor {
    private var monitors: [Any] = []

    func start(matching mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}
