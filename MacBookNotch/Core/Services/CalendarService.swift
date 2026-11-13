import AppKit
import EventKit
import Observation
import os

/// Events from the user's calendars for today, tomorrow, and the month the Calendar tab shows.
///
/// Access is requested only when the user clicks Connect in the Calendar tab.
@Observable
final class CalendarService {
    enum Access: Equatable {
        case notDetermined
        case granted
        /// Denied, restricted, or write-only access, none of which can read events.
        case denied
    }

    private(set) var access: Access
    /// Events from the start of today through tomorrow, and in `displayedMonth`, before the user's filters.
    private(set) var events: [CalendarEvent] = []
    /// The first day of the month the Calendar tab shows.
    private(set) var displayedMonth: Date
    /// Calendars that can hold events, for choosing which to show in Settings.
    private(set) var calendars: [CalendarInfo] = []
    /// The event to show beside the notch, updated every few seconds so it appears and disappears on time.
    private(set) var reminderEvent: CalendarEvent?

    nonisolated private static let logger = Logger(subsystem: "com.example.MacBookNotch", category: "Calendar")

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        access = Self.currentAccess()
        displayedMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    }

    /// Events after applying the user's calendar and all-day choices.
    var visibleEvents: [CalendarEvent] {
        CalendarAgenda.visible(
            events,
            hiddenCalendarIDs: settings.hiddenCalendarIDs,
            includeAllDay: settings.showAllDayEvents
        )
    }

    func start() {
        guard observers.isEmpty else { return }
        for name in [Notification.Name.EKEventStoreChanged, .NSCalendarDayChanged, .NSSystemTimeZoneDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        refresh()

        tickTask = Task { [weak self] in
            var ticks = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self else { return }
                ticks += 1
                // Reload events every five minutes as a backstop; update the reminder every tick.
                if ticks % 20 == 0 { self.refresh() } else { self.updateReminder() }
            }
        }
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        tickTask?.cancel()
    }

    /// Shows the system prompt for calendar access.
    func requestAccess() {
        Self.logger.notice("Asking for calendar access; status is \(Self.statusName, privacy: .public)")
        Task {
            do {
                let granted = try await store.requestFullAccessToEvents()
                Self.logger.notice("Calendar access request returned \(granted); status is \(Self.statusName, privacy: .public)")
            } catch {
                Self.logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
            }
            refresh()
        }
    }

    /// Loads the events for the month containing `date`, for the Calendar tab.
    func showMonth(containing date: Date) {
        let month = Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
        guard month != displayedMonth else { return }
        displayedMonth = month
        refresh()
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// Opens Calendar with the event's details showing, or just opens Calendar if the event can't be linked to.
    func showInCalendarApp(_ event: CalendarEvent) {
        if let url = event.calendarAppURL, NSWorkspace.shared.open(url) { return }
        openCalendarApp()
    }

    func join(_ event: CalendarEvent) {
        if let url = event.meetingURL {
            NSWorkspace.shared.open(url)
        }
    }

    func refresh() {
        let newAccess = Self.currentAccess()
        if newAccess != access {
            Self.logger.notice("Calendar access changed to \(String(describing: newAccess), privacy: .public)")
            access = newAccess
        }
        guard access == .granted else {
            events = []
            calendars = []
            updateReminder()
            return
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? startOfToday
        // Reminders need today and tomorrow even while the tab shows another month.
        let ranges = [
            DateInterval(start: startOfToday, end: endOfTomorrow),
            calendar.dateInterval(of: .month, for: displayedMonth),
        ].compactMap { $0 }
        calendars = store.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, color: Self.rgb($0.cgColor)) }
        var seen = Set<String>()
        let loaded = ranges
            .flatMap { store.events(matching: store.predicateForEvents(withStart: $0.start, end: $0.end, calendars: nil)) }
            .map(Self.makeEvent)
            .filter { seen.insert($0.id).inserted }
        apply(loaded)
    }

    /// Replaces the loaded events. Exposed to tests; the app calls `refresh()`.
    func apply(_ loaded: [CalendarEvent]) {
        if loaded != events {
            events = loaded
        }
        updateReminder()
    }

    /// Recomputes the reminder. Exposed so settings changes take effect immediately.
    func updateReminder() {
        let leadTime = TimeInterval(settings.meetingReminderMinutes * 60)
        let event = CalendarAgenda.reminder(visibleEvents, now: .now, leadTime: leadTime)
        if event != reminderEvent {
            reminderEvent = event
        }
    }

    private static var statusName: String {
        String(describing: EKEventStore.authorizationStatus(for: .event).rawValue)
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private static func makeEvent(_ event: EKEvent) -> CalendarEvent {
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
        return CalendarEvent(
            id: "\(identifier)@\(event.startDate.timeIntervalSinceReferenceDate)",
            title: event.title?.isEmpty == false ? event.title : "Untitled event",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            calendarID: event.calendar?.calendarIdentifier ?? "",
            color: rgb(event.calendar?.cgColor),
            location: event.location,
            meetingURL: MeetingLink.find(in: [event.url?.absoluteString, event.location, event.notes]),
            calendarAppURL: calendarAppURL(for: event)
        )
    }

    /// The link Calendar uses to show an event's details. EventKit builds it for each occurrence, but only privately,
    /// so this falls back to the `ical://ekevent/` form Calendar handles, which shows the first occurrence of a repeating event.
    private static func calendarAppURL(for event: EKEvent) -> URL? {
        let selector = NSSelectorFromString("showEventURLString")
        if event.responds(to: selector),
           let string = event.perform(selector)?.takeUnretainedValue() as? String,
           let url = URL(string: string), url.scheme == "ical" {
            return url
        }
        return URL(string: "ical://ekevent/\(event.calendarItemIdentifier)?method=show&options=more")
    }

    private static func rgb(_ color: CGColor?) -> CalendarColor? {
        guard let color,
              let converted = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3
        else { return nil }
        return CalendarColor(red: components[0], green: components[1], blue: components[2])
    }
}
