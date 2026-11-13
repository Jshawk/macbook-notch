import SwiftUI
import UniformTypeIdentifiers

/// Root view of the notch panel. Draws the notch shape at the top center and resizes it for each presentation.
struct NotchView: View {
    let model: NotchViewModel
    let context: NotchContext

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var presentation: NotchPresentation {
        model.presentation
    }

    private var shape: NotchShape {
        switch presentation {
        case .collapsed:
            NotchShape(topCornerRadius: NotchLayout.collapsedTopRadius, bottomCornerRadius: NotchLayout.collapsedBottomRadius)
        case .compact:
            NotchShape(topCornerRadius: NotchLayout.collapsedTopRadius, bottomCornerRadius: NotchLayout.compactBottomRadius)
        case .banner:
            NotchShape(topCornerRadius: NotchLayout.collapsedTopRadius, bottomCornerRadius: NotchLayout.bannerBottomRadius)
        case .expanded:
            NotchShape(topCornerRadius: NotchLayout.expandedTopRadius, bottomCornerRadius: NotchLayout.expandedBottomRadius)
        }
    }

    private var acceptsDrops: Bool {
        context.settings.isVisible(.shelf)
    }

    var body: some View {
        let size = model.layout.shapeSize(for: presentation)

        ZStack(alignment: .top) {
            shape.fill(Theme.Colors.notchBackground)

            switch presentation {
            case .expanded:
                ExpandedNotchContent(model: model, context: context)
                    .padding(.horizontal, NotchLayout.expandedTopRadius)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            case .compact, .banner:
                if let activity = model.activities.current {
                    CompactActivityView(
                        activity: activity,
                        notchSize: model.layout.geometry.notchRect.size,
                        artwork: context.music.artwork,
                        showsBanner: presentation == .banner
                    )
                    .padding(.horizontal, NotchLayout.collapsedTopRadius)
                    .frame(height: size.height, alignment: .top)
                    .transition(.opacity)
                }
            case .collapsed:
                EmptyView()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture {
            guard presentation != .expanded else { return }
            // Clicking an activity opens the tab it belongs to.
            model.expand(showing: model.activities.current.map(\.tab))
        }
        .onDrop(of: acceptsDrops ? [.fileURL] : [], isTargeted: dropTargetBinding, perform: addDroppedFiles)
        .shadow(color: .black.opacity(presentation == .expanded ? 0.45 : 0), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notch")
        .accessibilityLabel("Notch")
        .accessibilityAddTraits(presentation == .expanded ? [] : .isButton)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : Theme.Motion.notch, value: presentation)
        .animation(reduceMotion ? nil : Theme.Motion.notch, value: model.layout)
        .onChange(of: model.activities.current) { oldValue, newValue in
            announce(newValue, replacing: oldValue)
        }
        .preferredColorScheme(.dark)
    }

    private var dropTargetBinding: Binding<Bool> {
        Binding(
            get: { model.isDropTargeted },
            set: { model.setDropTargeted($0) }
        )
    }

    private func addDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        let shelf = context.shelf
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in shelf.add([url]) }
            }
        }
        return !providers.isEmpty
    }

    /// Tells VoiceOver about new alerts. Ongoing timers and music aren't announced every time they change.
    private func announce(_ activity: NotchActivity?, replacing old: NotchActivity?) {
        guard let activity, activity.kind != old?.kind, activity.isAnnounced else { return }
        AccessibilityNotification.Announcement(CompactActivityView.accessibilityDescription(of: activity)).post()
    }
}

extension NotchActivity {
    /// The tab with more detail about this activity.
    var tab: NotchTab {
        switch self {
        case .timer, .timerFinished: .timers
        case .powerChanged: .home
        case .meetingSoon: .calendar
        case .nowPlaying, .trackChanged: .music
        }
    }
}
