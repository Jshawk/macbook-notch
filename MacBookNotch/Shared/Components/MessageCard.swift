import SwiftUI

/// A one-row message with actions, for tabs that have nothing to show yet or need permission.
/// It stays only as tall as its content, so an empty tab doesn't fill the notch with a large blank card.
/// A tab that shows one should report it in `NotchContext.showsMessage(on:)`, so the open notch gets shorter.
struct MessageCard<Actions: View>: View {
    let systemImage: String
    let title: String
    var detail: String?
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.secondaryText)
                .frame(width: 30, height: 30)
                .background(Theme.Colors.controlBackground, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.Spacing.medium)
            HStack(spacing: Theme.Spacing.small) {
                actions
            }
            .buttonStyle(PillButtonStyle())
            .fixedSize()
        }
        .padding(.horizontal, Theme.Spacing.medium)
        .padding(.vertical, Theme.Spacing.small + 2)
        .background(
            Theme.Colors.cardBackground,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}
