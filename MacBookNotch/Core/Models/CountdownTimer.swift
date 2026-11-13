import Foundation

/// A countdown that stores its deadline rather than a ticking counter, so it survives sleep and relaunch.
nonisolated struct CountdownTimer: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var label: String
    var duration: TimeInterval
    /// When a running timer finishes. `nil` while paused.
    var endDate: Date?
    /// Time left when the timer was paused. `nil` while running.
    var pausedRemaining: TimeInterval?

    init(id: UUID = UUID(), label: String, duration: TimeInterval, startedAt start: Date) {
        self.id = id
        self.label = label
        self.duration = duration
        endDate = start.addingTimeInterval(duration)
        pausedRemaining = nil
    }

    var isPaused: Bool {
        endDate == nil
    }

    func remaining(at now: Date) -> TimeInterval {
        if let endDate {
            return max(0, endDate.timeIntervalSince(now))
        }
        return pausedRemaining ?? 0
    }

    func isFinished(at now: Date) -> Bool {
        guard let endDate else { return false }
        return endDate <= now
    }

    mutating func pause(at now: Date) {
        guard !isPaused else { return }
        pausedRemaining = remaining(at: now)
        endDate = nil
    }

    mutating func resume(at now: Date) {
        guard isPaused else { return }
        endDate = now.addingTimeInterval(pausedRemaining ?? 0)
        pausedRemaining = nil
    }

    /// A label for display, falling back to the duration when the user didn't name the timer.
    var displayLabel: String {
        label.isEmpty ? Self.format(duration: duration) + " timer" : label
    }

    /// Remaining time as a clock reading, such as "4:05" or "1:02:03". Rounds up so a fresh 5 minute timer reads "5:00".
    static func clockString(for remaining: TimeInterval) -> String {
        let total = Int(max(0, remaining).rounded(.up))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func format(duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: duration) ?? ""
    }
}
