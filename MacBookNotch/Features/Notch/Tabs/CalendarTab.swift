import SwiftUI

/// A month calendar beside the events of the day selected in it, with Join buttons for video calls.
/// Double-clicking an event shows it in Calendar.
struct CalendarTab: View {
    let calendar: CalendarService

    var body: some View {
        switch calendar.access {
        case .granted:
            TimelineView(.periodic(from: .now, by: 15)) { timeline in
                MonthAgenda(calendar: calendar, now: timeline.date)
            }
        case .notDetermined:
            MessageCard(
                systemImage: "calendar",
                title: "See your next meeting here",
                detail: "MacBook Notch reads the calendars on this Mac. Nothing leaves your Mac."
            ) {
                Button("Connect Calendar…") { calendar.requestAccess() }
            }
        case .denied:
            MessageCard(
                systemImage: "lock",
                title: "MacBook Notch can't read your calendars",
                detail: "Turn on full access in System Settings > Privacy & Security > Calendars."
            ) {
                Button("Open System Settings") { calendar.openPrivacySettings() }
            }
        }
    }
}

/// The month grid beside the selected day's events. Opening the tab selects today.
struct MonthAgenda: View {
    let calendar: CalendarService
    let now: Date

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    var body: some View {
        let events = calendar.visibleEvents
        HStack(spacing: Theme.Spacing.medium) {
            MonthGrid(
                month: calendar.displayedMonth,
                selection: selectedDay,
                now: now,
                hasEvents: { !CalendarAgenda.events(events, on: $0).isEmpty },
                select: { selectedDay = $0 },
                changeMonth: changeMonth,
                showToday: { select(Calendar.current.startOfDay(for: now)) }
            )
            .frame(width: 210)
            DayAgendaCard(
                day: selectedDay,
                events: CalendarAgenda.events(events, on: selectedDay),
                now: now,
                join: calendar.join,
                show: calendar.showInCalendarApp,
                openCalendar: calendar.openCalendarApp
            )
        }
        .onAppear { calendar.showMonth(containing: selectedDay) }
    }

    private func select(_ day: Date) {
        selectedDay = day
        calendar.showMonth(containing: day)
    }

    /// Moves by whole months, selecting today in the current month and the 1st in any other.
    private func changeMonth(by months: Int) {
        let current = Calendar.current
        guard let month = current.date(byAdding: .month, value: months, to: calendar.displayedMonth) else { return }
        select(current.isDate(month, equalTo: now, toGranularity: .month) ? current.startOfDay(for: now) : month)
    }
}

private struct MonthGrid: View {
    let month: Date
    let selection: Date
    let now: Date
    let hasEvents: (Date) -> Bool
    let select: (Date) -> Void
    let changeMonth: (Int) -> Void
    let showToday: () -> Void

    var body: some View {
        let weeks = CalendarAgenda.monthGrid(for: month)
        let symbols = CalendarAgenda.weekdaySymbols()
        WidgetCard(padding: Theme.Spacing.small) {
            VStack(spacing: 1) {
                HStack(spacing: 0) {
                    Button(action: showToday) {
                        Text(month.formatted(.dateTime.month(.wide).year()))
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.leading, Theme.Spacing.xSmall)
                    }
                    .buttonStyle(.plain)
                    .help("Go to Today")
                    Spacer(minLength: 0)
                    MonthStepButton(systemImage: "chevron.left", label: "Previous Month") { changeMonth(-1) }
                    MonthStepButton(systemImage: "chevron.right", label: "Next Month") { changeMonth(1) }
                }
                .frame(height: 16)

                HStack(spacing: 0) {
                    ForEach(symbols.indices, id: \.self) { index in
                        Text(symbols[index])
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.Colors.tertiaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)

                ForEach(weeks.indices, id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { weekday in
                            Group {
                                if let day = weeks[week][weekday] {
                                    DayCell(
                                        day: day,
                                        isSelected: Calendar.current.isDate(day, inSameDayAs: selection),
                                        isToday: Calendar.current.isDate(day, inSameDayAs: now),
                                        hasEvents: hasEvents(day),
                                        select: select
                                    )
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(month.formatted(.dateTime.month(.wide).year()))
    }
}

private struct MonthStepButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.Colors.secondaryText)
                .frame(width: 20, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let select: (Date) -> Void

    var body: some View {
        Button {
            select(day)
        } label: {
            Text(day, format: .dateTime.day())
                .font(.system(size: 10, weight: isSelected || isToday ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .frame(width: 22)
                .frame(maxHeight: .infinity)
                .background {
                    if isSelected {
                        Capsule().fill(isToday ? Theme.Colors.accent : Theme.Colors.primaryText)
                    }
                }
                .overlay(alignment: .bottom) {
                    if hasEvents && !isSelected {
                        Circle()
                            .fill(isToday ? Theme.Colors.accent : Theme.Colors.secondaryText)
                            .frame(width: 3, height: 3)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue(hasEvents ? "Has events" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var textColor: Color {
        if isSelected { return .black }
        if isToday { return Theme.Colors.accent }
        return hasEvents ? Theme.Colors.primaryText : Theme.Colors.secondaryText
    }
}

/// The selected day's events. Today's list scrolls to the first event that hasn't ended.
private struct DayAgendaCard: View {
    let day: Date
    let events: [CalendarEvent]
    let now: Date
    let join: (CalendarEvent) -> Void
    let show: (CalendarEvent) -> Void
    let openCalendar: () -> Void

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Spacer(minLength: 0)
                    Button(action: openCalendar) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Open Calendar")
                    .accessibilityLabel("Open Calendar")
                }
                if events.isEmpty {
                    Text("No events")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Spacer(minLength: 0)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            VStack(spacing: 2) {
                                ForEach(events) { event in
                                    AgendaRow(event: event, day: day, now: now, join: join, show: show)
                                        .id(event.id)
                                }
                            }
                        }
                        .scrollIndicators(events.count > 3 ? .visible : .never)
                        .onAppear { scrollToCurrent(proxy) }
                        .onChange(of: day) { scrollToCurrent(proxy) }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Events on \(day.formatted(date: .complete, time: .omitted))")
    }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        for (offset, name) in [(1, "Tomorrow"), (-1, "Yesterday")] {
            if let other = calendar.date(byAdding: .day, value: offset, to: now), calendar.isDate(day, inSameDayAs: other) {
                return name
            }
        }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard Calendar.current.isDate(day, inSameDayAs: now),
              let current = events.first(where: { !$0.isAllDay && !$0.hasEnded(at: now) })
        else { return }
        proxy.scrollTo(current.id, anchor: .top)
    }
}

private struct AgendaRow: View {
    let event: CalendarEvent
    let day: Date
    let now: Date
    let join: (CalendarEvent) -> Void
    let show: (CalendarEvent) -> Void

    @State private var isHovered = false

    var body: some View {
        let hasEnded = event.hasEnded(at: now)
        let isInProgress = event.isInProgress(at: now)
        HStack(spacing: Theme.Spacing.small) {
            Text(timeLabel)
                .font(.system(size: 11, weight: isInProgress ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(isInProgress ? Theme.Colors.positive : Theme.Colors.secondaryText)
                .frame(width: 58, alignment: .leading)
            Circle()
                .fill(event.color.map(Color.init) ?? Theme.Colors.accent)
                .frame(width: 6, height: 6)
            Text(event.title)
                .font(.system(size: 12, weight: isInProgress ? .semibold : .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            if event.meetingURL != nil && !hasEnded {
                let isJoinable = isInProgress || event.start.timeIntervalSince(now) <= 10 * 60
                Button {
                    join(event)
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isJoinable ? .black : Theme.Colors.primaryText)
                        .frame(width: 22, height: 18)
                        .background(isJoinable ? Theme.Colors.positive : Theme.Colors.controlBackground, in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Join")
                .accessibilityLabel("Join \(event.title)")
            }
        }
        .frame(height: 22)
        .opacity(hasEnded && !event.isAllDay ? 0.45 : 1)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Theme.Colors.cardBackground : .clear)
                .padding(.horizontal, -Theme.Spacing.xSmall)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { show(event) }
        .help("Double-click to show in Calendar")
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Show in Calendar") { show(event) }
    }

    /// "All day", "Now", the start time, or for an event continuing from an earlier day, when it ends.
    private var timeLabel: String {
        if event.isAllDay { return "All day" }
        if event.isInProgress(at: now) { return "Now" }
        if event.start < Calendar.current.startOfDay(for: day) {
            return "–" + event.end.formatted(date: .omitted, time: .shortened)
        }
        return event.start.formatted(date: .omitted, time: .shortened)
    }
}
