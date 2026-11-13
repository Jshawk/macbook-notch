import Foundation

/// Services the notch views read from and act on.
struct NotchContext {
    let settings: AppSettings
    let battery: BatteryMonitor
    let timers: TimerStore
    let shelf: ShelfStore
    let checklist: ChecklistStore
    let music: MusicController
    let audio: AudioOutputController
    let calendar: CalendarService
    let openSettings: () -> Void
    /// Makes the panel the key window so text fields can receive typing.
    let focusPanel: () -> Void
    /// Previews a file with Quick Look.
    let quickLook: (URL) -> Void
}
