import AppKit
import Observation
import SwiftUI

/// Owns the notch panel: places it on the chosen screen and routes pointer and keyboard events to the view model.
final class NotchWindowController {
    private let settings: AppSettings
    private let viewModel: NotchViewModel
    private let panel: NotchPanel
    private let quickLookPresenter = QuickLookPresenter()
    private let pointerMonitor = EventMonitor()
    private let clickMonitor = EventMonitor()
    private var screenObserver: NSObjectProtocol?
    private var isRunning = false

    init(
        settings: AppSettings,
        battery: BatteryMonitor,
        timers: TimerStore,
        shelf: ShelfStore,
        checklist: ChecklistStore,
        music: MusicController,
        audio: AudioOutputController,
        calendar: CalendarService,
        activities: ActivityCenter,
        openSettings: @escaping () -> Void
    ) {
        let geometry = ScreenSelector.screen(for: settings.displayPreference)?.notchGeometry
            ?? NotchGeometry(
                screenFrame: .zero,
                safeAreaTopInset: 0,
                auxiliaryTopLeftWidth: nil,
                auxiliaryTopRightWidth: nil,
                menuBarHeight: 0
            )

        self.settings = settings
        viewModel = NotchViewModel(geometry: geometry, settings: settings, activities: activities)
        let panel = NotchPanel(contentRect: viewModel.layout.panelFrame)
        self.panel = panel

        panel.quickLookPresenter = quickLookPresenter
        var quickLook: (URL) -> Void = { _ in }
        let context = NotchContext(
            settings: settings,
            battery: battery,
            timers: timers,
            shelf: shelf,
            checklist: checklist,
            music: music,
            audio: audio,
            calendar: calendar,
            openSettings: openSettings,
            focusPanel: { panel.makeKey() },
            quickLook: { quickLook($0) }
        )
        viewModel.showsMessage = context.showsMessage(on:)
        let hostingView = NotchHostingView(rootView: NotchView(model: viewModel, context: context))
        hostingView.onPointerEvent = { [weak self] in self?.updatePointer() }
        panel.contentView = hostingView

        panel.onCancel = { [weak self] in self?.viewModel.collapse() }
        quickLook = { [weak self] url in self?.showQuickLook(url) }
        viewModel.onStateChange = { [weak self] state in
            if state == .collapsed { self?.returnKeyboardFocus() }
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateScreen() }
        }

        pointerMonitor.start(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.updatePointer()
        }
        clickMonitor.start(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.viewModel.mouseDown(at: NSEvent.mouseLocation)
        }

        observeSettings()
        observeLayout()
        updateScreen()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        pointerMonitor.stop()
        clickMonitor.stop()
        panel.orderOut(nil)
    }

    /// Opens or closes the notch from the keyboard. When opening, the panel takes keyboard focus so Escape closes it.
    func toggleFromKeyboard() {
        guard isRunning, panel.isVisible else { return }
        if viewModel.state == .expanded {
            viewModel.collapse()
        } else {
            viewModel.expand(holding: .keyboard)
            panel.makeKey()
            updatePointer()
        }
    }

    /// Previews a file with Quick Look, keeping the notch open until the preview closes.
    private func showQuickLook(_ url: URL) {
        viewModel.hold(.previewing)
        quickLookPresenter.show([url], from: panel) { [weak self] in
            self?.viewModel.release(.previewing)
        }
    }

    private var shouldShowPanel: Bool {
        viewModel.geometry.hasHardwareNotch || settings.showOnDisplaysWithoutNotch
    }

    private func updateScreen() {
        guard isRunning, let screen = ScreenSelector.screen(for: settings.displayPreference) else {
            panel.orderOut(nil)
            return
        }

        viewModel.updateGeometry(screen.notchGeometry)
        updatePanelFrame()

        if shouldShowPanel {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
        updatePointer()
    }

    private func updatePanelFrame() {
        let frame = viewModel.layout.panelFrame
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
    }

    private func updatePointer() {
        let isOverNotch = viewModel.pointerMoved(to: NSEvent.mouseLocation)
        // Only capture the mouse while it is over the notch so the rest of the panel stays click-through.
        panel.ignoresMouseEvents = !isOverNotch
    }

    /// Hands keyboard focus back to the app the user was working in once the notch closes.
    private func returnKeyboardFocus() {
        guard panel.isKeyWindow else { return }
        Task { @MainActor [weak self] in
            // Let the collapse animation finish so the panel doesn't visibly blink.
            try? await Task.sleep(for: .milliseconds(450))
            guard let self, self.viewModel.state == .collapsed, self.panel.isKeyWindow else { return }
            self.panel.orderOut(nil)
            if self.isRunning, self.shouldShowPanel {
                self.panel.orderFrontRegardless()
            }
        }
    }

    private func observeSettings() {
        withObservationTracking {
            _ = settings.displayPreference
            _ = settings.showOnDisplaysWithoutNotch
        } onChange: { [weak self] in
            // `onChange` fires before the new value is stored, so apply it on the next turn of the run loop.
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.updateScreen()
                self.observeSettings()
            }
        }
    }

    /// Keeps the panel frame in step with the layout and refreshes mouse capture when the notch changes shape.
    private func observeLayout() {
        withObservationTracking {
            _ = viewModel.layout
            _ = viewModel.presentation
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.updatePanelFrame()
                self.updatePointer()
                self.observeLayout()
            }
        }
    }
}
