import SwiftUI

struct BatteryWidget: View {
    /// `nil` on Macs without an internal battery.
    let status: BatteryStatus?

    var body: some View {
        WidgetCard {
            if let status {
                BatteryGauge(status: status)
            } else {
                Label("No battery", systemImage: "powerplug")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct BatteryGauge: View {
    let status: BatteryStatus

    private var tint: Color {
        if status.isCharging { return Theme.Colors.positive }
        if status.level <= 0.2 { return Theme.Colors.warning }
        return Theme.Colors.primaryText
    }

    private var detail: String {
        if status.isCharging { return "Charging" }
        if status.isPluggedIn { return "Plugged in" }
        return "On battery"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Gauge(value: status.level) {
                EmptyView()
            } currentValueLabel: {
                Image(systemName: status.isCharging ? "bolt.fill" : "battery.100")
                    .font(.system(size: 12, weight: .semibold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)

            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                Text("\(status.percentage)%")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(status.percentage) percent, \(detail)")
    }
}

#Preview {
    HStack {
        BatteryWidget(status: BatteryStatus(level: 0.82, isCharging: true, isPluggedIn: true))
        BatteryWidget(status: BatteryStatus(level: 0.12, isCharging: false, isPluggedIn: false))
        BatteryWidget(status: nil)
    }
    .frame(width: 480, height: 110)
    .padding()
    .background(.black)
}
