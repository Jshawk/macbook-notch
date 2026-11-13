import Foundation
import Testing
@testable import MacBookNotch

struct CountdownTimerTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func countsDownFromDeadline() {
        let timer = CountdownTimer(label: "", duration: 300, startedAt: start)

        #expect(timer.remaining(at: start) == 300)
        #expect(timer.remaining(at: start.addingTimeInterval(120)) == 180)
        #expect(!timer.isFinished(at: start.addingTimeInterval(299)))
        #expect(timer.isFinished(at: start.addingTimeInterval(300)))
        #expect(timer.remaining(at: start.addingTimeInterval(1000)) == 0)
    }

    @Test func pauseFreezesRemainingTime() {
        var timer = CountdownTimer(label: "", duration: 300, startedAt: start)

        timer.pause(at: start.addingTimeInterval(100))

        #expect(timer.isPaused)
        #expect(timer.remaining(at: start.addingTimeInterval(5000)) == 200)
        #expect(!timer.isFinished(at: start.addingTimeInterval(5000)))
    }

    @Test func resumeSetsNewDeadline() {
        var timer = CountdownTimer(label: "", duration: 300, startedAt: start)
        timer.pause(at: start.addingTimeInterval(100))

        timer.resume(at: start.addingTimeInterval(1000))

        #expect(!timer.isPaused)
        #expect(timer.endDate == start.addingTimeInterval(1200))
    }

    @Test func formatsClockReadings() {
        #expect(CountdownTimer.clockString(for: 300) == "5:00")
        #expect(CountdownTimer.clockString(for: 299.2) == "5:00")
        #expect(CountdownTimer.clockString(for: 65) == "1:05")
        #expect(CountdownTimer.clockString(for: 3723) == "1:02:03")
        #expect(CountdownTimer.clockString(for: -4) == "0:00")
    }

    @Test func labelFallsBackToDuration() {
        let unnamed = CountdownTimer(label: "", duration: 900, startedAt: start)
        let named = CountdownTimer(label: "Laundry", duration: 900, startedAt: start)

        #expect(unnamed.displayLabel.contains("15"))
        #expect(named.displayLabel == "Laundry")
    }

    @Test func roundTripsThroughCodable() throws {
        var timer = CountdownTimer(label: "Tea", duration: 180, startedAt: start)
        timer.pause(at: start.addingTimeInterval(30))

        let decoded = try JSONDecoder().decode(CountdownTimer.self, from: JSONEncoder().encode(timer))

        #expect(decoded == timer)
    }
}
