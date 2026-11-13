import SwiftUI

/// Activity content on either side of the hardware notch while the notch is compact,
/// plus a line of text below it when the notch shows a banner.
struct CompactActivityView: View {
    let activity: NotchActivity
    let notchSize: CGSize
    /// Album artwork, shown for the song that's playing.
    var artwork: NSImage?
    var showsBanner = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leading
                    .frame(width: NotchLayout.compactSideWidth, alignment: .leading)
                    .padding(.leading, Theme.Spacing.medium)
                Spacer(minLength: notchSize.width - Theme.Spacing.medium * 2)
                trailing
                    .frame(width: NotchLayout.compactSideWidth, alignment: .trailing)
                    .padding(.trailing, Theme.Spacing.medium)
            }
            .frame(height: notchSize.height)

            if showsBanner, let text = bannerText {
                text
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, Theme.Spacing.large)
                    .frame(height: NotchLayout.bannerLineHeight - Theme.Spacing.xSmall, alignment: .center)
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(Theme.Colors.primaryText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityDescription(of: activity))
        .accessibilityIdentifier("notch.activity")
    }

    @ViewBuilder
    private var leading: some View {
        switch activity {
        case .timer(let timer):
            Image(systemName: timer.isPaused ? "pause.fill" : "timer")
                .foregroundStyle(Theme.Colors.accent)
        case .timerFinished:
            Image(systemName: "bell.fill")
                .foregroundStyle(Theme.Colors.accent)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
        case .powerChanged(let isPluggedIn, _):
            Image(systemName: isPluggedIn ? "bolt.fill" : "powerplug")
                .foregroundStyle(isPluggedIn ? Theme.Colors.positive : Theme.Colors.secondaryText)
        case .meetingSoon(let event):
            Image(systemName: "calendar")
                .foregroundStyle(event.color.map(Color.init) ?? Theme.Colors.accent)
        case .nowPlaying, .trackChanged:
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity {
        case .timer(let timer):
            if let endDate = timer.endDate, endDate > .now {
                Text(timerInterval: Date.now...endDate, countsDown: true)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(CountdownTimer.clockString(for: timer.remaining(at: .now)))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        case .timerFinished:
            Text("Done")
                .foregroundStyle(Theme.Colors.accent)
        case .powerChanged(_, let level):
            Text(level, format: .percent.precision(.fractionLength(0)))
        case .meetingSoon(let event):
            TimelineView(.periodic(from: .now, by: 15)) { timeline in
                Text(CalendarAgenda.relativeStart(of: event, now: timeline.date))
                    .foregroundStyle(event.isInProgress(at: timeline.date) ? Theme.Colors.positive : Theme.Colors.primaryText)
            }
        case .nowPlaying, .trackChanged:
            EqualizerBars(isAnimating: !reduceMotion)
        }
    }

    /// The banner's line of text: the song's title, then its artist in a dimmer color.
    private var bannerText: Text? {
        guard case .trackChanged(let track) = activity else { return nil }
        let title = Text(track.title).foregroundColor(Theme.Colors.primaryText)
        guard !track.artist.isEmpty else { return title }
        return Text("\(title)  \(Text(track.artist).foregroundColor(Theme.Colors.secondaryText))")
    }

    static func accessibilityDescription(of activity: NotchActivity) -> String {
        switch activity {
        case .timer(let timer):
            let remaining = CountdownTimer.format(duration: timer.remaining(at: .now).rounded(.up))
            return timer.isPaused
                ? "\(timer.displayLabel) paused, \(remaining) left"
                : "\(timer.displayLabel), \(remaining) left"
        case .timerFinished(let label):
            return "\(label) finished"
        case .powerChanged(let isPluggedIn, let level):
            let percent = Int((level * 100).rounded())
            return isPluggedIn ? "Power connected, \(percent) percent" : "Power disconnected, \(percent) percent"
        case .nowPlaying(let track), .trackChanged(let track):
            return track.artist.isEmpty ? "Now playing: \(track.title)" : "Now playing: \(track.title) by \(track.artist)"
        case .meetingSoon(let event):
            let when = CalendarAgenda.relativeStart(of: event, now: .now)
            return when == "Now" ? "\(event.title) is starting now" : "\(event.title) starts \(when)"
        }
    }
}

/// Three bars that bounce while music plays, or sit still when Reduce Motion is on.
private struct EqualizerBars: View {
    let isAnimating: Bool

    private static let restingHeights: [CGFloat] = [0.5, 0.9, 0.65]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !isAnimating)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .frame(width: 3, height: 14 * height(for: index, at: time))
                }
            }
            .frame(height: 14)
        }
        .foregroundStyle(Theme.Colors.positive)
    }

    private func height(for index: Int, at time: TimeInterval) -> CGFloat {
        guard isAnimating else { return Self.restingHeights[index] }
        let speed = [5.1, 6.7, 4.3][index]
        let phase = Double(index) * 1.7
        return 0.3 + 0.7 * CGFloat(abs(sin(time * speed + phase)))
    }
}
