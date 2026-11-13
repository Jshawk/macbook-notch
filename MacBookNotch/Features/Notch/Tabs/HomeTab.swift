import SwiftUI

/// The clock, today's checklist, and, on Macs with a battery, the battery gauge.
struct HomeTab: View {
    let battery: BatteryMonitor
    let checklist: ChecklistStore
    let model: NotchViewModel
    let focusPanel: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            ClockWidget()
                .frame(width: 150)
            ChecklistWidget(checklist: checklist, model: model, focusPanel: focusPanel)
            if battery.status != nil {
                BatteryWidget(status: battery.status)
                    .frame(width: 164)
            }
        }
    }
}
