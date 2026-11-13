import Foundation
import Observation

/// User preferences, persisted to `UserDefaults`.
@Observable
final class AppSettings {
    enum Keys {
        static let expansionTrigger = "expansionTrigger"
        static let hoverDelay = "hoverDelay"
        static let displayPreference = "displayPreference"
        static let showOnDisplaysWithoutNotch = "showOnDisplaysWithoutNotch"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let tabOrder = "tabOrder"
        static let hiddenTabs = "hiddenTabs"
        static let showMusicActivity = "showMusicActivity"
        static let showTrackChanges = "showTrackChanges"
        static let hiddenCalendarIDs = "hiddenCalendarIDs"
        static let showAllDayEvents = "showAllDayEvents"
        static let meetingReminderMinutes = "meetingReminderMinutes"
        static let showChargingAlerts = "showChargingAlerts"
        static let timerSound = "timerSound"
        static let timerNotifications = "timerNotifications"
        static let toggleShortcut = "toggleShortcut"
        /// Settings from before the notch had tabs; removed on launch.
        static let retired = ["showBattery", "widgetOrder", "hiddenWidgets"]
    }

    static let hoverDelayRange: ClosedRange<Double> = 0...1

    var expansionTrigger: ExpansionTrigger {
        didSet { defaults.set(expansionTrigger.rawValue, forKey: Keys.expansionTrigger) }
    }

    /// Seconds the pointer must rest on the notch before it opens.
    var hoverDelay: Double {
        didSet { defaults.set(hoverDelay, forKey: Keys.hoverDelay) }
    }

    var displayPreference: DisplayPreference {
        didSet { defaults.set(displayPreference.rawValue, forKey: Keys.displayPreference) }
    }

    var showOnDisplaysWithoutNotch: Bool {
        didSet { defaults.set(showOnDisplaysWithoutNotch, forKey: Keys.showOnDisplaysWithoutNotch) }
    }

    var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    /// Every tab, in display order, including hidden ones.
    var tabOrder: [NotchTab] {
        didSet { defaults.set(tabOrder.map(\.rawValue), forKey: Keys.tabOrder) }
    }

    var hiddenTabs: Set<NotchTab> {
        didSet { defaults.set(hiddenTabs.map(\.rawValue).sorted(), forKey: Keys.hiddenTabs) }
    }

    /// Whether the collapsed notch widens to show the song that's playing.
    var showMusicActivity: Bool {
        didSet { defaults.set(showMusicActivity, forKey: Keys.showMusicActivity) }
    }

    /// Whether a banner shows the new song under the notch when the track changes.
    var showTrackChanges: Bool {
        didSet { defaults.set(showTrackChanges, forKey: Keys.showTrackChanges) }
    }

    /// Calendars whose events the notch doesn't show, by EventKit identifier.
    var hiddenCalendarIDs: Set<String> {
        didSet { defaults.set(hiddenCalendarIDs.sorted(), forKey: Keys.hiddenCalendarIDs) }
    }

    var showAllDayEvents: Bool {
        didSet { defaults.set(showAllDayEvents, forKey: Keys.showAllDayEvents) }
    }

    /// Minutes before an event starts to show it beside the notch. 0 turns reminders off.
    var meetingReminderMinutes: Int {
        didSet { defaults.set(meetingReminderMinutes, forKey: Keys.meetingReminderMinutes) }
    }

    static let meetingReminderChoices = [0, 1, 2, 5, 10, 15]

    var showChargingAlerts: Bool {
        didSet { defaults.set(showChargingAlerts, forKey: Keys.showChargingAlerts) }
    }

    var timerSound: Bool {
        didSet { defaults.set(timerSound, forKey: Keys.timerSound) }
    }

    var timerNotifications: Bool {
        didSet { defaults.set(timerNotifications, forKey: Keys.timerNotifications) }
    }

    /// Shortcut that opens and closes the notch from anywhere. `nil` when not set.
    var toggleShortcut: HotKey? {
        didSet {
            // Optionals start out as nil, so loading this in `init` runs `didSet`. Skip writing then,
            // so a one-launch override such as `-toggleShortcut` isn't saved permanently.
            guard !isLoading else { return }
            if let data = toggleShortcut.flatMap({ try? JSONEncoder().encode($0) }) {
                defaults.set(data, forKey: Keys.toggleShortcut)
            } else {
                defaults.removeObject(forKey: Keys.toggleShortcut)
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isLoading = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrate(defaults)
        defaults.register(defaults: [
            Keys.expansionTrigger: ExpansionTrigger.hover.rawValue,
            Keys.hoverDelay: 0.15,
            Keys.displayPreference: DisplayPreference.builtIn.rawValue,
            Keys.showOnDisplaysWithoutNotch: true,
            Keys.showMenuBarIcon: true,
            Keys.showChargingAlerts: true,
            Keys.showMusicActivity: true,
            Keys.showTrackChanges: true,
            Keys.showAllDayEvents: true,
            Keys.meetingReminderMinutes: 5,
            Keys.timerSound: true,
            Keys.timerNotifications: false,
        ])

        expansionTrigger = defaults.string(forKey: Keys.expansionTrigger)
            .flatMap(ExpansionTrigger.init(rawValue:)) ?? .hover
        hoverDelay = defaults.double(forKey: Keys.hoverDelay)
            .clamped(to: Self.hoverDelayRange)
        displayPreference = defaults.string(forKey: Keys.displayPreference)
            .flatMap(DisplayPreference.init(rawValue:)) ?? .builtIn
        showOnDisplaysWithoutNotch = defaults.bool(forKey: Keys.showOnDisplaysWithoutNotch)
        showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        tabOrder = NotchTab.normalizedOrder(defaults.stringArray(forKey: Keys.tabOrder) ?? [])
        hiddenTabs = Set((defaults.stringArray(forKey: Keys.hiddenTabs) ?? []).compactMap(NotchTab.init(rawValue:)))
        showMusicActivity = defaults.bool(forKey: Keys.showMusicActivity)
        showTrackChanges = defaults.bool(forKey: Keys.showTrackChanges)
        hiddenCalendarIDs = Set(defaults.stringArray(forKey: Keys.hiddenCalendarIDs) ?? [])
        showAllDayEvents = defaults.bool(forKey: Keys.showAllDayEvents)
        meetingReminderMinutes = max(0, defaults.integer(forKey: Keys.meetingReminderMinutes))
        showChargingAlerts = defaults.bool(forKey: Keys.showChargingAlerts)
        timerSound = defaults.bool(forKey: Keys.timerSound)
        timerNotifications = defaults.bool(forKey: Keys.timerNotifications)
        toggleShortcut = defaults.data(forKey: Keys.toggleShortcut)
            .flatMap { try? JSONDecoder().decode(HotKey.self, from: $0) }
        isLoading = false
    }

    /// Visible tabs in display order.
    var visibleTabs: [NotchTab] {
        tabOrder.filter { !hiddenTabs.contains($0) }
    }

    func isVisible(_ tab: NotchTab) -> Bool {
        !hiddenTabs.contains(tab)
    }

    /// Shows or hides a tab. The last visible tab can't be hidden, so the notch always has something to show.
    func setVisible(_ tab: NotchTab, _ isVisible: Bool) {
        if isVisible {
            hiddenTabs.remove(tab)
        } else if visibleTabs != [tab] {
            hiddenTabs.insert(tab)
        }
    }

    /// Moves a tab one place earlier (`offset: -1`) or later (`offset: 1`).
    func moveTab(_ tab: NotchTab, by offset: Int) {
        guard let index = tabOrder.firstIndex(of: tab) else { return }
        let destination = index + offset
        guard tabOrder.indices.contains(destination) else { return }
        tabOrder.swapAt(index, destination)
    }

    private static func migrate(_ defaults: UserDefaults) {
        for key in Keys.retired where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
