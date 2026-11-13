import SwiftUI

/// Running timers on the left; presets and custom entry on the right.
struct TimersTab: View {
    let timers: TimerStore
    let model: NotchViewModel
    let focusPanel: () -> Void

    @State private var isEnteringCustom = false

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            WidgetCard {
                if timers.timers.isEmpty {
                    Label("No timers running", systemImage: "timer")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: Theme.Spacing.xSmall) {
                            ForEach(timers.timers) { timer in
                                TimerRow(timer: timer, timers: timers)
                            }
                        }
                    }
                    // Show whole rows only; more timers scroll rather than peeking out half-cut.
                    .frame(height: Self.listHeight(for: timers.timers.count))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .scrollIndicators(timers.timers.count > Self.visibleRows ? .visible : .never)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Running timers")

            WidgetCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Start a timer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.secondaryText)
                    HStack(spacing: Theme.Spacing.xSmall) {
                        ForEach(TimerStore.presets.prefix(3), id: \.self, content: presetButton)
                    }
                    if isEnteringCustom {
                        CustomTimerEntry(timers: timers) {
                            isEnteringCustom = false
                            model.release(.editing)
                        }
                    } else {
                        HStack(spacing: Theme.Spacing.xSmall) {
                            ForEach(TimerStore.presets.dropFirst(3), id: \.self, content: presetButton)
                            ChipButton(title: "Custom…") {
                                model.hold(.editing)
                                focusPanel()
                                isEnteringCustom = true
                            }
                            .accessibilityLabel("Custom timer")
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(width: 210)
        }
    }

    private func presetButton(_ duration: TimeInterval) -> some View {
        ChipButton(title: Self.presetTitle(duration)) {
            timers.start(duration: duration)
        }
        .accessibilityLabel("Start \(CountdownTimer.format(duration: duration)) timer")
    }

    private static let visibleRows = 3

    private static func listHeight(for count: Int) -> CGFloat {
        let rows = CGFloat(min(count, visibleRows))
        return rows * TimerRow.height + max(0, rows - 1) * Theme.Spacing.xSmall
    }

    private static func presetTitle(_ duration: TimeInterval) -> String {
        duration >= 3600 ? "\(Int(duration / 3600))h" : "\(Int(duration / 60))m"
    }
}

private struct TimerRow: View {
    static let height: CGFloat = 22

    let timer: CountdownTimer
    let timers: TimerStore

    var body: some View {
        HStack(spacing: Theme.Spacing.small) {
            Group {
                if let endDate = timer.endDate, endDate > .now {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                } else {
                    Text(CountdownTimer.clockString(for: timer.remaining(at: .now)))
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .monospacedDigit()

            Text(timer.displayLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            IconButton(systemImage: timer.isPaused ? "play.fill" : "pause.fill") {
                timer.isPaused ? timers.resume(timer.id) : timers.pause(timer.id)
            }
            .accessibilityLabel(timer.isPaused ? "Resume \(timer.displayLabel)" : "Pause \(timer.displayLabel)")

            IconButton(systemImage: "xmark") {
                timers.cancel(timer.id)
            }
            .accessibilityLabel("Cancel \(timer.displayLabel)")
        }
        .frame(height: Self.height)
    }
}

/// Minutes and an optional label, typed into the notch.
private struct CustomTimerEntry: View {
    let timers: TimerStore
    let onDone: () -> Void

    @State private var minutes = ""
    @State private var label = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case minutes
        case label
    }

    private var duration: TimeInterval? {
        guard let value = Double(minutes.replacingOccurrences(of: ",", with: ".")), value > 0, value <= 24 * 60 else {
            return nil
        }
        return value * 60
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xSmall) {
            TextField("Min", text: $minutes)
                .focused($focusedField, equals: .minutes)
                .frame(width: 36)
                .accessibilityLabel("Minutes")
            TextField("Label", text: $label)
                .focused($focusedField, equals: .label)
                .accessibilityLabel("Timer label")
            IconButton(systemImage: "play.fill", action: start)
                .disabled(duration == nil)
                .accessibilityLabel("Start timer")
            IconButton(systemImage: "xmark", action: onDone)
                .accessibilityLabel("Cancel")
        }
        .textFieldStyle(.roundedBorder)
        .controlSize(.small)
        .onSubmit(start)
        .task {
            // Give the panel a moment to become the key window before moving focus into it.
            try? await Task.sleep(for: .milliseconds(50))
            focusedField = .minutes
        }
    }

    private func start() {
        guard let duration else { return }
        timers.start(duration: duration, label: label)
        onDone()
    }
}

/// A small capsule button used for timer presets.
private struct ChipButton: View {
    var title: String?
    var systemImage: String?
    let action: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    init(systemImage: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let title {
                    Text(title)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 22)
            .background(Theme.Colors.controlBackground, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct IconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 20, height: 20)
                .background(Theme.Colors.controlBackground, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
