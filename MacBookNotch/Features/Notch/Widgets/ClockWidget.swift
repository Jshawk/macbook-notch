import SwiftUI

struct ClockWidget: View {
    var body: some View {
        WidgetCard {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(context.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ClockWidget()
        .frame(width: 260, height: 110)
        .padding()
        .background(.black)
}
