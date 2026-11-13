import Foundation
import Testing
@testable import MacBookNotch

struct CalendarAgendaTests {
    private let calendar = Calendar(identifier: .gregorian)
    /// 10:00 on a fixed day.
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func event(
        _ title: String,
        startsIn minutes: Double,
        lasting duration: Double = 30,
        allDay: Bool = false,
        calendarID: String = "work"
    ) -> CalendarEvent {
        let start = now.addingTimeInterval(minutes * 60)
        return CalendarEvent(
            id: title,
            title: title,
            start: start,
            end: start.addingTimeInterval(duration * 60),
            isAllDay: allDay,
            calendarID: calendarID,
            color: nil,
            location: nil,
            meetingURL: nil
        )
    }

    @Test func filtersHiddenCalendarsAndAllDayEvents() {
        let events = [
            event("Later", startsIn: 60),
            event("Holiday", startsIn: -600, lasting: 1440, allDay: true),
            event("Private", startsIn: 10, calendarID: "home"),
            event("Soon", startsIn: 5),
        ]

        let visible = CalendarAgenda.visible(events, hiddenCalendarIDs: ["home"], includeAllDay: false)

        #expect(visible.map(\.title) == ["Soon", "Later"])
    }

    @Test func remindsWithinLeadTimeAndBrieflyAfterStart() {
        let meeting = event("Standup", startsIn: 4)

        #expect(CalendarAgenda.reminder([meeting], now: now, leadTime: 5 * 60) == meeting)
        #expect(CalendarAgenda.reminder([meeting], now: now, leadTime: 3 * 60) == nil, "Too early")
        #expect(CalendarAgenda.reminder([meeting], now: now, leadTime: 0) == nil, "Reminders off")

        let started = event("Standup", startsIn: -0.5)
        #expect(CalendarAgenda.reminder([started], now: now, leadTime: 5 * 60) == started)
        let startedAWhileAgo = event("Standup", startsIn: -2)
        #expect(CalendarAgenda.reminder([startedAWhileAgo], now: now, leadTime: 5 * 60) == nil)
    }

    @Test func remindersIgnoreAllDayEvents() {
        let holiday = event("Holiday", startsIn: 2, lasting: 1440, allDay: true)

        #expect(CalendarAgenda.reminder([holiday], now: now, leadTime: 5 * 60) == nil)
    }

    @Test func describesRelativeStart() {
        #expect(CalendarAgenda.relativeStart(of: event("A", startsIn: -5), now: now, calendar: calendar) == "Now")
        #expect(CalendarAgenda.relativeStart(of: event("A", startsIn: 4.2), now: now, calendar: calendar) == "in 5 min")
        #expect(CalendarAgenda.relativeStart(of: event("A", startsIn: 0.1), now: now, calendar: calendar) == "in 1 min")
        #expect(CalendarAgenda.relativeStart(of: event("A", startsIn: 26 * 60), now: now, calendar: calendar).hasPrefix("Tomorrow"))
    }

    @Test func eventsOnDayIncludeOnesRunningIntoIt() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func at(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
        }
        func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEvent {
            CalendarEvent(
                id: title, title: title, start: start, end: end, isAllDay: allDay,
                calendarID: "work", color: nil, location: nil, meetingURL: nil
            )
        }
        let events = [
            event("Yesterday", at(14, 9), at(14, 10)),
            event("Overnight", at(14, 22), at(15, 2)),
            event("Holiday", at(15, 0), at(16, 0), allDay: true),
            event("Reminder", at(15, 12), at(15, 12)),
            event("Tomorrow", at(16, 0), at(16, 1)),
        ]

        #expect(CalendarAgenda.events(events, on: at(15, 8), calendar: calendar).map(\.title) == ["Overnight", "Holiday", "Reminder"])
    }

    @Test func monthGridStartsOnFirstWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // September 2026 starts on a Tuesday and has 30 days.
        let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15))!

        calendar.firstWeekday = 1
        let sundayFirst = CalendarAgenda.monthGrid(for: september, calendar: calendar)
        #expect(sundayFirst.count == 5)
        #expect(sundayFirst.allSatisfy { $0.count == 7 })
        #expect(sundayFirst[0].prefix(2).allSatisfy { $0 == nil })
        #expect(sundayFirst[0][2].map { calendar.component(.day, from: $0) } == 1)
        #expect(sundayFirst.flatMap { $0 }.compactMap { $0 }.count == 30)
        #expect(CalendarAgenda.weekdaySymbols(calendar: calendar).first == calendar.veryShortStandaloneWeekdaySymbols[0])

        calendar.firstWeekday = 2
        let mondayFirst = CalendarAgenda.monthGrid(for: september, calendar: calendar)
        #expect(mondayFirst[0][1].map { calendar.component(.day, from: $0) } == 1)
        #expect(CalendarAgenda.weekdaySymbols(calendar: calendar).first == calendar.veryShortStandaloneWeekdaySymbols[1])
    }
}

struct MeetingLinkTests {
    @Test func findsCommonMeetingLinks() {
        let links = [
            "https://us02web.zoom.us/j/123456789?pwd=abc",
            "https://meet.google.com/abc-defg-hij",
            "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc",
            "https://company.webex.com/meet/someone",
            "https://facetime.apple.com/join#v=1&p=abc",
        ]

        for link in links {
            #expect(MeetingLink.find(in: ["Join: \(link) (call in)"]) == URL(string: link), "\(link)")
        }
    }

    @Test func ignoresOrdinaryLinks() {
        #expect(MeetingLink.find(in: ["Agenda: https://docs.google.com/document/d/abc"]) == nil)
        #expect(MeetingLink.find(in: ["https://zoom.us/pricing"]) == nil)
        #expect(MeetingLink.find(in: ["https://meet.google.com/"]) == nil)
        #expect(MeetingLink.find(in: [nil, "", "Room 4B"]) == nil)
    }

    @Test func checksFieldsInOrder() {
        let url = "https://zoom.us/j/111"
        let notes = "Backup: https://meet.google.com/aaa-bbbb-ccc"

        #expect(MeetingLink.find(in: [url, "Room 4B", notes]) == URL(string: url))
        #expect(MeetingLink.find(in: [nil, "Room 4B", notes]) == URL(string: "https://meet.google.com/aaa-bbbb-ccc"))
    }
}

@MainActor
struct CalendarActivityTests {
    private let defaults = TestSupport.makeDefaults()

    @Test func upcomingMeetingOutranksRunningTimer() {
        let settings = AppSettings(defaults: defaults)
        let timers = TimerStore(defaults: defaults)
        let calendar = CalendarService(settings: settings)
        let center = ActivityCenter(timers: timers, calendar: calendar, settings: settings)
        timers.start(duration: 600)

        let start = Date.now.addingTimeInterval(120)
        calendar.apply([CalendarEvent(
            id: "standup", title: "Standup", start: start, end: start.addingTimeInterval(900),
            isAllDay: false, calendarID: "work", color: nil, location: nil, meetingURL: nil
        )])

        #expect(center.current?.kind == .meetingSoon)
    }

    @Test func hiddenCalendarsDontRemind() {
        let settings = AppSettings(defaults: defaults)
        let calendar = CalendarService(settings: settings)
        settings.hiddenCalendarIDs = ["work"]

        let start = Date.now.addingTimeInterval(120)
        calendar.apply([CalendarEvent(
            id: "standup", title: "Standup", start: start, end: start.addingTimeInterval(900),
            isAllDay: false, calendarID: "work", color: nil, location: nil, meetingURL: nil
        )])

        #expect(calendar.reminderEvent == nil)
    }
}
