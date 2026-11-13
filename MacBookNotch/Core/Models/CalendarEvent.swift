import Foundation

/// A calendar event, copied out of EventKit so it can be compared, tested, and shown without the event store.
nonisolated struct CalendarEvent: Equatable, Identifiable, Sendable {
    /// Unique per occurrence: repeating events share an EventKit identifier, so the start date is included.
    let id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendarID: String
    var color: CalendarColor?
    var location: String?
    var meetingURL: URL?
    /// Opens this occurrence in Calendar with its details showing.
    var calendarAppURL: URL? = nil

    func isInProgress(at now: Date) -> Bool {
        start <= now && now < end
    }

    func hasEnded(at now: Date) -> Bool {
        end <= now
    }
}

/// A calendar the user can choose to show or hide.
nonisolated struct CalendarInfo: Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    var color: CalendarColor?
}

/// A color that can cross actor boundaries and be tested, unlike `CGColor`.
nonisolated struct CalendarColor: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
}

/// Rules for which events the notch shows.
nonisolated enum CalendarAgenda {
    /// A reminder stays up for this long after the event starts, showing "Now".
    static let reminderGracePeriod: TimeInterval = 60

    /// Events after hiding the user's excluded calendars and, optionally, all-day events. Sorted by start.
    static func visible(_ events: [CalendarEvent], hiddenCalendarIDs: Set<String>, includeAllDay: Bool) -> [CalendarEvent] {
        events
            .filter { !hiddenCalendarIDs.contains($0.calendarID) && (includeAllDay || !$0.isAllDay) }
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    /// Events that happen at any time on `day`, including ones that started earlier and run into it.
    static func events(_ events: [CalendarEvent], on day: Date, calendar: Calendar = .current) -> [CalendarEvent] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return events.filter { $0.start < dayEnd && ($0.end > dayStart || $0.start >= dayStart) }
    }

    /// The days of the month containing `date`, split into weeks that start on the calendar's first weekday.
    /// Cells before the 1st and after the last day of the month are nil.
    static func monthGrid(for date: Date, calendar: Calendar = .current) -> [[Date?]] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let dayCount = calendar.range(of: .day, in: .month, for: date)?.count
        else { return [] }
        let leading = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        cells += (0..<dayCount).map { calendar.date(byAdding: .day, value: $0, to: month.start) }
        cells += Array(repeating: nil, count: (7 - cells.count % 7) % 7)
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// One-letter weekday names in the order `monthGrid` uses.
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The event to remind the user about: one starting within `leadTime`, or that started less than a minute ago.
    static func reminder(_ events: [CalendarEvent], now: Date, leadTime: TimeInterval) -> CalendarEvent? {
        guard leadTime > 0 else { return nil }
        return events
            .filter { event in
                !event.isAllDay
                    && event.start.timeIntervalSince(now) <= leadTime
                    && now.timeIntervalSince(event.start) < reminderGracePeriod
            }
            .min { $0.start < $1.start }
    }

    /// A short description of when an event starts relative to now, such as "in 5 min", "Now", or "Tomorrow 9:00 AM".
    static func relativeStart(of event: CalendarEvent, now: Date, calendar: Calendar = .current) -> String {
        if event.isInProgress(at: now) { return "Now" }
        let minutes = Int((event.start.timeIntervalSince(now) / 60).rounded(.up))
        if minutes < 60 { return "in \(max(minutes, 1)) min" }
        let time = event.start.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(event.start, inSameDayAs: now) { return time }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(event.start, inSameDayAs: tomorrow) {
            return "Tomorrow \(time)"
        }
        return event.start.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

/// Finds video call links in an event's URL, location, and notes.
nonisolated enum MeetingLink {
    /// Hosts of supported meeting services, with the path a join link starts with. A prefix ending in "/" needs
    /// more after it, such as a meeting ID; one that doesn't can be the whole path, as in FaceTime's `/join#…`.
    private static let services: [(host: String, pathPrefix: String)] = [
        ("zoom.us", "/j/"),
        ("zoom.us", "/my/"),
        ("zoom.us", "/w/"),
        ("zoomgov.com", "/j/"),
        ("meet.google.com", "/"),
        ("teams.microsoft.com", "/l/meetup-join"),
        ("teams.live.com", "/meet"),
        ("webex.com", "/"),
        ("facetime.apple.com", "/join"),
        ("whereby.com", "/"),
    ]

    static func find(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                if let url = match.url, isMeetingURL(url) {
                    return url
                }
            }
        }
        return nil
    }

    static func isMeetingURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host()?.lowercased()
        else { return false }
        let path = url.path()
        return services.contains { service in
            (host == service.host || host.hasSuffix("." + service.host))
                && path.hasPrefix(service.pathPrefix)
                && (path.count > service.pathPrefix.count || !service.pathPrefix.hasSuffix("/"))
        }
    }
}
