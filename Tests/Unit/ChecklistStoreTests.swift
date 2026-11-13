import Foundation
import Testing
@testable import MacBookNotch

@MainActor
struct ChecklistStoreTests {
    private let defaults = TestSupport.makeDefaults()
    private let calendar = Calendar(identifier: .gregorian)

    @Test func addsTrimmedTasksUpToTheLimit() {
        let checklist = ChecklistStore(defaults: defaults)

        #expect(!checklist.add("   "))
        for index in 1...ChecklistStore.maximumItems {
            #expect(checklist.add("  Task \(index) "))
        }
        #expect(!checklist.canAdd)
        #expect(!checklist.add("One too many"))
        #expect(checklist.items.map(\.title).first == "Task 1")
        #expect(checklist.items.count == ChecklistStore.maximumItems)
    }

    @Test func togglesAndRemovesTasks() {
        let checklist = ChecklistStore(defaults: defaults)
        checklist.add("Write report")
        checklist.add("Call Sam")
        let report = checklist.items[0].id

        checklist.toggle(report)
        #expect(checklist.items[0].isDone)
        #expect(checklist.completedCount == 1)
        checklist.toggle(report)
        #expect(!checklist.items[0].isDone)

        checklist.remove(report)
        #expect(checklist.items.map(\.title) == ["Call Sam"])
    }

    @Test func persistsAcrossRelaunch() {
        let first = ChecklistStore(defaults: defaults)
        first.add("Water plants")
        first.toggle(first.items[0].id)

        let second = ChecklistStore(defaults: defaults)
        #expect(second.items.map(\.title) == ["Water plants"])
        #expect(second.items[0].isDone)
    }

    @Test func nextDayClearsFinishedTasksAndKeepsTheRest() {
        var today = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let checklist = ChecklistStore(defaults: defaults, now: { today }, calendar: calendar)
        checklist.add("Done today")
        checklist.add("Still to do")
        checklist.toggle(checklist.items[0].id)

        checklist.clearTasksFinishedBeforeToday()
        #expect(checklist.items.count == 2, "Finished tasks stay visible for the rest of the day")

        today = calendar.date(byAdding: .day, value: 1, to: today)!
        checklist.clearTasksFinishedBeforeToday()
        #expect(checklist.items.map(\.title) == ["Still to do"])

        let relaunched = ChecklistStore(defaults: defaults, now: { today }, calendar: calendar)
        #expect(relaunched.items.map(\.title) == ["Still to do"])
    }
}
