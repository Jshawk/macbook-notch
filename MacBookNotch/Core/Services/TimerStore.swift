import Foundation
import Observation

/// Running and paused countdowns, persisted so they survive relaunch.
@Observable
final class TimerStore {
    static let presets: [TimeInterval] = [5, 15, 25, 60].map { $0 * 60 }

    private(set) var timers: [CountdownTimer]

    /// Called for each timer that reaches zero, after it has been removed from `timers`.
    @ObservationIgnored var onFinish: ((CountdownTimer) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey: String
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var completionTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, storageKey: String = "timers", now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.now = now
        timers = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([CountdownTimer].self, from: $0) } ?? []
    }

    /// The timer to feature while the notch is compact: the next to finish, otherwise the newest paused timer.
    var nextTimer: CountdownTimer? {
        let running = timers.filter { !$0.isPaused }
        if let soonest = running.min(by: { ($0.endDate ?? .distantFuture) < ($1.endDate ?? .distantFuture) }) {
            return soonest
        }
        return timers.last
    }

    @discardableResult
    func start(duration: TimeInterval, label: String = "") -> CountdownTimer {
        let timer = CountdownTimer(
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: max(1, duration),
            startedAt: now()
        )
        timers.append(timer)
        didChange()
        return timer
    }

    func pause(_ id: CountdownTimer.ID) {
        update(id) { $0.pause(at: now()) }
    }

    func resume(_ id: CountdownTimer.ID) {
        update(id) { $0.resume(at: now()) }
    }

    func cancel(_ id: CountdownTimer.ID) {
        timers.removeAll { $0.id == id }
        didChange()
    }

    /// Removes timers whose deadline has passed and reports them through `onFinish`.
    /// Call after launch and after the Mac wakes, since timers may have ended in the meantime.
    func checkForFinishedTimers() {
        let date = now()
        let finished = timers.filter { $0.isFinished(at: date) }
        if !finished.isEmpty {
            timers.removeAll { $0.isFinished(at: date) }
        }
        didChange()
        finished.forEach { onFinish?($0) }
    }

    private func update(_ id: CountdownTimer.ID, _ change: (inout CountdownTimer) -> Void) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        change(&timers[index])
        didChange()
    }

    private func didChange() {
        if let data = try? JSONEncoder().encode(timers) {
            defaults.set(data, forKey: storageKey)
        }
        scheduleCompletionCheck()
    }

    private func scheduleCompletionCheck() {
        completionTask?.cancel()
        completionTask = nil

        guard let deadline = timers.compactMap(\.endDate).min() else { return }
        let delay = max(0, deadline.timeIntervalSince(now()))
        completionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.checkForFinishedTimers()
        }
    }
}
