import Foundation
import IOKit.ps
import Observation

/// Publishes the internal battery's status. `status` is `nil` on Macs without a battery.
@Observable
final class BatteryMonitor {
    private(set) var status: BatteryStatus?

    /// Called with the previous and new status whenever the status changes.
    @ObservationIgnored var onChange: ((_ old: BatteryStatus?, _ new: BatteryStatus?) -> Void)?

    @ObservationIgnored private var runLoopSource: CFRunLoopSource?

    func start() {
        guard runLoopSource == nil else { return }
        refresh()

        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            // The source is added to the main run loop, so this callback runs on the main thread.
            MainActor.assumeIsolated {
                Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue().refresh()
            }
        }, context)?.takeRetainedValue()

        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
    }

    func stop() {
        guard let runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        self.runLoopSource = nil
    }

    func refresh() {
        let newStatus = Self.readStatus()
        guard newStatus != status else { return }
        let oldStatus = status
        status = newStatus
        onChange?(oldStatus, newStatus)
    }

    private static func readStatus() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any]
            else { continue }

            if let status = BatteryStatus(powerSourceDescription: description) {
                return status
            }
        }
        return nil
    }
}
