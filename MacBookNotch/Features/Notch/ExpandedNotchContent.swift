import SwiftUI

/// Content shown while the notch is open: a header row beside the hardware notch, then the selected tab.
struct ExpandedNotchContent: View {
    let model: NotchViewModel
    let context: NotchContext

    private var notchSize: CGSize {
        model.layout.geometry.notchRect.size
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: notchSize.height)

            tabContent
                .padding(.horizontal, NotchLayout.contentInset)
                .padding(.bottom, Theme.Spacing.medium)
                .padding(.top, Theme.Spacing.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(Theme.Colors.primaryText)
        .accessibilityIdentifier("notch.expanded")
    }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch model.visibleTab {
            case .home:
                HomeTab(battery: context.battery, checklist: context.checklist, model: model, focusPanel: context.focusPanel)
            case .calendar:
                CalendarTab(calendar: context.calendar)
            case .music:
                MusicTab(music: context.music, audio: context.audio, model: model)
            case .timers:
                TimersTab(timers: context.timers, model: model, focusPanel: context.focusPanel)
            case .shelf:
                ShelfTab(shelf: context.shelf, model: model, quickLook: context.quickLook)
            }
        }
        .id(model.visibleTab)
        .transition(.opacity)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.small) {
            TabBar(tabs: context.settings.visibleTabs, selection: model.visibleTab) { tab in
                withAnimation(.easeInOut(duration: 0.15)) { model.select(tab) }
            }

            // Keep header items out from under the camera housing.
            Spacer(minLength: notchSize.width + Theme.Spacing.large)

            Button(action: openSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("notch.settings")
        }
        .padding(.horizontal, Theme.Spacing.medium)
    }

    private func openSettings() {
        // Close first so the notch doesn't cover the settings window's title bar.
        model.collapse()
        context.openSettings()
    }
}

/// Icon buttons for switching tabs. ⌘1, ⌘2, and so on also switch tabs while the notch has keyboard focus.
private struct TabBar: View {
    let tabs: [NotchTab]
    let selection: NotchTab
    let select: (NotchTab) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xSmall) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                let isSelected = tab == selection
                Button {
                    select(tab)
                } label: {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.Colors.primaryText : Theme.Colors.secondaryText)
                        .frame(width: 28, height: 22)
                        .background(isSelected ? Theme.Colors.controlBackground : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .help(tab.title)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("notch.tab.\(tab.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }
}

extension NotchContext {
    /// Whether the tab shows only a one-row `MessageCard`, matching the states the tabs above handle that way.
    func showsMessage(on tab: NotchTab) -> Bool {
        switch tab {
        case .music:
            if case .nowPlaying = music.state { false } else { true }
        case .calendar:
            calendar.access != .granted
        case .home, .timers, .shelf:
            false
        }
    }
}
