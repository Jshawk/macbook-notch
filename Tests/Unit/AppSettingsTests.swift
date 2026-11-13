import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import MacBookNotch

@MainActor
struct AppSettingsTests {
    private let defaults = TestSupport.makeDefaults()

    @Test func providesDefaults() {
        let settings = AppSettings(defaults: defaults)

        #expect(settings.expansionTrigger == .hover)
        #expect(settings.hoverDelay == 0.15)
        #expect(settings.displayPreference == .builtIn)
        #expect(settings.showOnDisplaysWithoutNotch)
        #expect(settings.showMenuBarIcon)
        #expect(settings.tabOrder == NotchTab.allCases)
        #expect(settings.visibleTabs == NotchTab.allCases)
        #expect(settings.showMusicActivity)
        #expect(settings.showTrackChanges)
        #expect(settings.showAllDayEvents)
        #expect(settings.meetingReminderMinutes == 5)
        #expect(settings.hiddenCalendarIDs.isEmpty)
        #expect(settings.showChargingAlerts)
        #expect(settings.timerSound)
        #expect(!settings.timerNotifications)
        #expect(settings.toggleShortcut == nil)
    }

    @Test func persistsChanges() {
        let settings = AppSettings(defaults: defaults)
        let shortcut = HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.command, .option], keyLabel: "N")
        settings.expansionTrigger = .click
        settings.hoverDelay = 0.5
        settings.displayPreference = .primary
        settings.showOnDisplaysWithoutNotch = false
        settings.showMenuBarIcon = false
        settings.setVisible(.music, false)
        settings.moveTab(.shelf, by: -1)
        settings.showMusicActivity = false
        settings.showTrackChanges = false
        settings.showAllDayEvents = false
        settings.meetingReminderMinutes = 10
        settings.hiddenCalendarIDs = ["holidays", "birthdays"]
        settings.showChargingAlerts = false
        settings.timerSound = false
        settings.timerNotifications = true
        settings.toggleShortcut = shortcut

        let reloaded = AppSettings(defaults: defaults)

        #expect(reloaded.expansionTrigger == .click)
        #expect(reloaded.hoverDelay == 0.5)
        #expect(reloaded.displayPreference == .primary)
        #expect(!reloaded.showOnDisplaysWithoutNotch)
        #expect(!reloaded.showMenuBarIcon)
        #expect(reloaded.tabOrder == [.home, .calendar, .music, .shelf, .timers])
        #expect(reloaded.visibleTabs == [.home, .calendar, .shelf, .timers])
        #expect(!reloaded.showMusicActivity)
        #expect(!reloaded.showTrackChanges)
        #expect(!reloaded.showAllDayEvents)
        #expect(reloaded.meetingReminderMinutes == 10)
        #expect(reloaded.hiddenCalendarIDs == ["holidays", "birthdays"])
        #expect(!reloaded.showChargingAlerts)
        #expect(!reloaded.timerSound)
        #expect(reloaded.timerNotifications)
        #expect(reloaded.toggleShortcut == shortcut)
    }

    @Test func clearingShortcutRemovesIt() {
        let settings = AppSettings(defaults: defaults)
        settings.toggleShortcut = HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.command], keyLabel: "N")

        settings.toggleShortcut = nil

        #expect(AppSettings(defaults: defaults).toggleShortcut == nil)
    }

    @Test func loadingDoesNotWriteAnything() throws {
        let defaults = RecordingDefaults(suiteName: "MacBookNotchTests.\(UUID().uuidString)")!
        let shortcut = HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.command], keyLabel: "N")
        defaults.set(try JSONEncoder().encode(shortcut), forKey: AppSettings.Keys.toggleShortcut)
        defaults.writtenKeys.removeAll()

        let settings = AppSettings(defaults: defaults)

        // Writing during load would save one-launch overrides, such as launch arguments, permanently.
        #expect(settings.toggleShortcut == shortcut)
        #expect(defaults.writtenKeys.isEmpty)
    }

    @Test func movingTabsStopsAtEdges() {
        let settings = AppSettings(defaults: defaults)

        settings.moveTab(.home, by: -1)
        settings.moveTab(.shelf, by: 1)

        #expect(settings.tabOrder == NotchTab.allCases)
    }

    @Test func lastVisibleTabCantBeHidden() {
        let settings = AppSettings(defaults: defaults)

        for tab in NotchTab.allCases {
            settings.setVisible(tab, false)
        }

        #expect(settings.visibleTabs == [.shelf])
    }

    @Test func normalizesStoredTabOrder() {
        #expect(NotchTab.normalizedOrder(["shelf", "bogus", "shelf", "home"]) == [.shelf, .home, .calendar, .music, .timers])
    }

    @Test func removesSettingsFromBeforeTabs() {
        defaults.set(false, forKey: "showBattery")
        defaults.set(["clock"], forKey: "widgetOrder")

        _ = AppSettings(defaults: defaults)

        #expect(defaults.object(forKey: "showBattery") == nil)
        #expect(defaults.object(forKey: "widgetOrder") == nil)
    }

    @Test func recoversFromInvalidStoredValues() {
        defaults.set("sideways", forKey: AppSettings.Keys.expansionTrigger)
        defaults.set(12.0, forKey: AppSettings.Keys.hoverDelay)
        defaults.set(Data("junk".utf8), forKey: AppSettings.Keys.toggleShortcut)

        let settings = AppSettings(defaults: defaults)

        #expect(settings.expansionTrigger == .hover)
        #expect(settings.hoverDelay == AppSettings.hoverDelayRange.upperBound)
        #expect(settings.toggleShortcut == nil)
    }
}

/// Records which keys are written, to check that loading settings has no side effects.
private final class RecordingDefaults: UserDefaults {
    var writtenKeys: [String] = []

    override func set(_ value: Any?, forKey defaultName: String) {
        writtenKeys.append(defaultName)
        super.set(value, forKey: defaultName)
    }

    override func removeObject(forKey defaultName: String) {
        writtenKeys.append(defaultName)
        super.removeObject(forKey: defaultName)
    }
}
