import SwiftUI

/// Rounded container for a single piece of content inside the expanded notch.
struct WidgetCard<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.medium
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                Theme.Colors.cardBackground,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
    }
}
