import Foundation
import Testing
@testable import MacBookNotch

@MainActor
struct TimerStoreTests {
    private let defaults = TestSupport.makeDefaults()
    private let clock = TestClock()

    private func makeStore() -> TimerStore {
        TimerStore(defaults: defaults, now: { [clock] in clock.now })
    }

    @Test func startsTimerWithTrimmedLabel() {
        let store = makeStore()

        let timer = store.start(duration: 300, label: "  Tea  ")

        #expect(store.timers == [timer])
        #expect(timer.label == "Tea")
        #expect(timer.endDate == clock.now.addingTimeInterval(300))
    }

    @Test func pausesResumesAndCancels() {
        let store = makeStore()
        let timer = store.start(duration: 300)

        clock.advance(by: 100)
        store.pause(timer.id)
        #expect(store.timers.first?.isPaused == true)

        clock.advance(by: 1000)
        store.resume(timer.id)
        #expect(store.timers.first?.remaining(at: clock.now) == 200)

        store.cancel(timer.id)
        #expect(store.timers.isEmpty)
    }

    @Test func nextTimerPrefersSoonestRunningTimer() {
        let store = makeStore()
        let long = store.start(duration: 600)
        let short = store.start(duration: 60)
        let paused = store.start(duration: 30)
        store.pause(paused.id)

        #expect(store.nextTimer?.id == short.id)

        store.cancel(short.id)
        #expect(store.nextTimer?.id == long.id)

        store.cancel(long.id)
        #expect(store.nextTimer?.id == paused.id)
    }

    @Test func reportsAndRemovesFinishedTimers() {
        let store = makeStore()
        var finished: [String] = []
        store.onFinish = { finished.append($0.label) }
        store.start(duration: 60, label: "Short")
        store.start(duration: 600, label: "Long")

        clock.advance(by: 61)
        store.checkForFinishedTimers()

        #expect(finished == ["Short"])
        #expect(store.timers.map(\.label) == ["Long"])
    }

    @Test func restoresTimersAfterRelaunch() {
        let store = makeStore()
        let running = store.start(duration: 600, label: "Running")
        let paused = store.start(duration: 600, label: "Paused")
        clock.advance(by: 100)
        store.pause(paused.id)

        let relaunched = makeStore()

        #expect(relaunched.timers.map(\.id) == [running.id, paused.id])
        #expect(relaunched.timers.last?.isPaused == true)
    }

    @Test func timersThatEndedWhileQuitAreReportedOnLaunch() {
        let store = makeStore()
        store.start(duration: 60, label: "While away")
        clock.advance(by: 3600)

        let relaunched = makeStore()
        var finished: [String] = []
        relaunched.onFinish = { finished.append($0.label) }
        relaunched.checkForFinishedTimers()

        #expect(finished == ["While away"])
        #expect(relaunched.timers.isEmpty)
    }
}
