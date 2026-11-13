import CoreGraphics
import Observation

/// Expansion state for the notch and the pointer rules that drive it.
@Observable
final class NotchViewModel {
    /// Reasons the expanded notch ignores the pointer leaving it.
    enum HoldReason: Hashable {
        /// Opened with the keyboard shortcut; closes with Escape, the shortcut, or a click elsewhere.
        case keyboard
        /// The user is typing into a field.
        case editing
        /// A file is being dragged out of the shelf; the source view has to stay alive until it lands.
        case dragging
        /// A menu from the notch is open; closing the notch would pull the menu's anchor out from under it.
        case menu
        /// A Quick Look preview of a shelf item is open.
        case previewing
    }

    private(set) var state: NotchState = .collapsed {
        didSet {
            if state != oldValue { onStateChange?(state) }
        }
    }
    private(set) var geometry: NotchGeometry
    private(set) var isPointerInside = false
    private(set) var isDropTargeted = false
    private(set) var holdReasons: Set<HoldReason> = []
    /// The tab the user last chose. It's kept between openings so the notch reopens where they left it.
    private(set) var selectedTab: NotchTab = .home

    @ObservationIgnored let settings: AppSettings
    @ObservationIgnored let activities: ActivityCenter
    @ObservationIgnored var onStateChange: ((NotchState) -> Void)?
    /// Whether a tab is showing only a one-row message, so the open notch can be shorter. It may read observable
    /// state, such as whether music is playing; the layout updates when that state changes.
    @ObservationIgnored var showsMessage: (NotchTab) -> Bool = { _ in false }
    @ObservationIgnored private let collapseDelay: Double
    @ObservationIgnored private var pendingTransition: Task<Void, Never>?

    /// - Parameter collapseDelay: Seconds to wait after the pointer leaves the expanded notch before closing it.
    init(geometry: NotchGeometry, settings: AppSettings, activities: ActivityCenter, collapseDelay: Double = 0.3) {
        self.geometry = geometry
        self.settings = settings
        self.activities = activities
        self.collapseDelay = collapseDelay
    }

    var layout: NotchLayout {
        NotchLayout(geometry: geometry, isCompact: showsMessage(visibleTab))
    }

    /// The tab to show: the selected one, or the first visible tab if the selected one was hidden in Settings.
    var visibleTab: NotchTab {
        let visible = settings.visibleTabs
        return visible.contains(selectedTab) ? selectedTab : visible.first ?? .home
    }

    var presentation: NotchPresentation {
        if state == .expanded { return .expanded }
        guard let activity = activities.current else { return .collapsed }
        return activity.kind == .trackChanged ? .banner : .compact
    }

    var interactiveRect: CGRect {
        layout.interactiveRect(for: presentation)
    }

    var isHeldOpen: Bool {
        !holdReasons.isEmpty
    }

    func updateGeometry(_ geometry: NotchGeometry) {
        guard geometry != self.geometry else { return }
        self.geometry = geometry
        collapse()
    }

    /// Updates hover state for a pointer location in global screen coordinates.
    /// - Returns: Whether the pointer is over the notch and the panel should receive mouse events.
    @discardableResult
    func pointerMoved(to point: CGPoint) -> Bool {
        let inside = interactiveRect.contains(point)
        guard inside != isPointerInside else { return inside }
        isPointerInside = inside

        switch (state, inside) {
        case (.collapsed, true):
            if settings.expansionTrigger == .hover {
                schedule(after: settings.hoverDelay) { [weak self] in self?.expand() }
            }
        case (.expanded, false):
            scheduleCollapseIfNotHeld()
        case (.collapsed, false), (.expanded, true):
            cancelPendingTransition()
        }
        return inside
    }

    /// Closes the notch when the user clicks somewhere else on screen.
    func mouseDown(at point: CGPoint) {
        if state == .expanded, !interactiveRect.contains(point), !holdReasons.contains(.dragging) {
            collapse()
        }
    }

    /// Opens the notch. Seeing the full notch counts as seeing any pending alerts, so they're dismissed.
    /// - Parameter tab: A tab to switch to, for example the one related to the activity the user clicked.
    func expand(holding reason: HoldReason? = nil, showing tab: NotchTab? = nil) {
        cancelPendingTransition()
        if let reason { holdReasons.insert(reason) }
        if let tab { select(tab) }
        state = .expanded
        activities.dismissAlerts()
    }

    func collapse() {
        cancelPendingTransition()
        holdReasons.removeAll()
        isDropTargeted = false
        state = .collapsed
    }

    func toggle(holding reason: HoldReason? = nil) {
        state == .expanded ? collapse() : expand(holding: reason)
    }

    /// Switches tabs. Hidden tabs can't be selected.
    func select(_ tab: NotchTab) {
        guard settings.isVisible(tab) else { return }
        selectedTab = tab
    }

    func hold(_ reason: HoldReason) {
        holdReasons.insert(reason)
        cancelPendingTransition()
    }

    /// Ends a hold. If the pointer already left, the notch closes as it would have without the hold.
    func release(_ reason: HoldReason) {
        guard holdReasons.remove(reason) != nil else { return }
        if state == .expanded, !isPointerInside {
            scheduleCollapseIfNotHeld()
        }
    }

    /// Opens the notch on the shelf while files are dragged over it.
    func setDropTargeted(_ isTargeted: Bool) {
        isDropTargeted = isTargeted
        guard isTargeted else { return }
        select(.shelf)
        if state == .collapsed {
            expand()
        }
    }

    private func scheduleCollapseIfNotHeld() {
        guard !isHeldOpen else { return }
        schedule(after: collapseDelay) { [weak self] in self?.collapse() }
    }

    private func schedule(after delay: Double, _ action: @escaping () -> Void) {
        cancelPendingTransition()
        guard delay > 0 else {
            action()
            return
        }
        pendingTransition = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            action()
        }
    }

    private func cancelPendingTransition() {
        pendingTransition?.cancel()
        pendingTransition = nil
    }
}
