import AppKit
import Observation
import SwiftUI

/// Creates the app's shared services and opens the notch panel.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let battery = BatteryMonitor()
    let launchAtLogin = LaunchAtLogin()
    let timers = TimerStore()
    let shelf = ShelfStore(storageURL: ShelfStore.defaultStorageURL)
    let checklist = ChecklistStore()
    let music = MusicController()
    let audio = AudioOutputController()
    let calendar: CalendarService
    let hotKeys = GlobalHotKeyCenter()
    let activities: ActivityCenter
    let timerAlerts: TimerAlerts

    private var notchController: NotchWindowController?
    private var wakeObserver: NSObjectProtocol?
    private lazy var settingsController = SettingsWindowController { [settings, launchAtLogin, hotKeys, timerAlerts, calendar] in
        SettingsView(
            settings: settings,
            launchAtLogin: launchAtLogin,
            hotKeys: hotKeys,
            timerAlerts: timerAlerts,
            calendar: calendar
        )
    }

    override init() {
        calendar = CalendarService(settings: settings)
        activities = ActivityCenter(timers: timers, music: music, calendar: calendar, settings: settings)
        timerAlerts = TimerAlerts(settings: settings)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app; keep the notch panel out of the way.
        guard !Self.isHostingUnitTests else { return }

        battery.onChange = { [weak self] old, new in
            guard let self, self.settings.showChargingAlerts,
                  let activity = NotchActivity.powerChange(from: old, to: new)
            else { return }
            self.activities.post(activity)
        }
        battery.start()

        timers.onFinish = { [weak self] timer in
            self?.activities.post(.timerFinished(label: timer.displayLabel))
            self?.timerAlerts.timerFinished(timer)
        }
        // Timers may have ended while the app wasn't running.
        timers.checkForFinishedTimers()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.timers.checkForFinishedTimers() }
        }

        music.onTrackChange = { [weak self] track in
            guard let self, self.settings.showTrackChanges else { return }
            self.activities.post(.trackChanged(track))
        }
        music.start()
        audio.start()
        calendar.start()
        observeCalendarSettings()

        let controller = NotchWindowController(
            settings: settings,
            battery: battery,
            timers: timers,
            shelf: shelf,
            checklist: checklist,
            music: music,
            audio: audio,
            calendar: calendar,
            activities: activities
        ) { [weak self] in
            self?.showSettings()
        }
        controller.start()
        notchController = controller

        hotKeys.onPress = { [weak controller] in controller?.toggleFromKeyboard() }
        registerShortcut()
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchController?.stop()
        battery.stop()
        music.stop()
        audio.stop()
        calendar.stop()
        hotKeys.unregisterAll()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    func showSettings() {
        settingsController.show()
    }

    /// Registers the toggle shortcut now and again whenever it changes in Settings.
    private func registerShortcut() {
        withObservationTracking {
            hotKeys.register(settings.toggleShortcut)
        } onChange: { [weak self] in
            Task { @MainActor in self?.registerShortcut() }
        }
    }

    /// Updates the meeting reminder right away when its settings change, rather than on the next tick.
    private func observeCalendarSettings() {
        withObservationTracking {
            _ = settings.meetingReminderMinutes
            _ = settings.hiddenCalendarIDs
            _ = settings.showAllDayEvents
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.calendar.updateReminder()
                self?.observeCalendarSettings()
            }
        }
    }

    private static var isHostingUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
