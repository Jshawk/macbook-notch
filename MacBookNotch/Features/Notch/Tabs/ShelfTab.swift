import AppKit
import QuickLookThumbnailing
import SwiftUI

/// Files dropped on the notch, ready to drag into another app, beside a place to drop files to AirDrop them.
struct ShelfTab: View {
    let shelf: ShelfStore
    let model: NotchViewModel
    let quickLook: (URL) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            shelfCard
            AirDropCard(shelf: shelf)
                .frame(width: 104)
        }
    }

    private var shelfCard: some View {
        WidgetCard {
            if shelf.items.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    HStack {
                        Text(shelf.items.count == 1 ? "1 item" : "\(shelf.items.count) items")
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Spacer()
                        Button("Clear") { shelf.clear() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.Colors.accent)
                            .disabled(!shelf.hasUnpinnedItems)
                            .help("Remove everything except pinned items. Files aren't deleted.")
                            .accessibilityLabel("Clear unpinned items")
                    }
                    .font(.system(size: 11, weight: .semibold))

                    ScrollView(.horizontal) {
                        HStack(spacing: Theme.Spacing.small) {
                            ForEach(shelf.sortedItems) { item in
                                ShelfItemView(item: item, shelf: shelf, model: model, quickLook: quickLook)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
            }
        }
        .overlay {
            if model.isDropTargeted {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Colors.accent, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("File shelf")
    }

    private var emptyState: some View {
        let isTargeted = model.isDropTargeted
        return VStack(spacing: Theme.Spacing.xSmall) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isTargeted ? Theme.Colors.accent : Theme.Colors.secondaryText)
            Text("Drop files here")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isTargeted ? Theme.Colors.accent : Theme.Colors.primaryText)
            Text("Files stay where they are. The shelf keeps a link to each one until you remove it.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct ShelfItemView: View {
    let item: ShelfItem
    let shelf: ShelfStore
    let model: NotchViewModel
    let quickLook: (URL) -> Void

    @State private var thumbnail: NSImage?

    private var isAvailable: Bool {
        shelf.isAvailable(item)
    }

    var body: some View {
        tile
            .overlay {
                ShelfItemInteraction(url: item.url, isAvailable: isAvailable, isPinned: item.isPinned, actions: actions)
            }
            .help(isAvailable ? item.url.path(percentEncoded: false) : "\(item.name) was moved or deleted")
            .modifier(accessibility)
            .task(id: item.url) {
                thumbnail = await ShelfActions.thumbnail(for: item.url)
            }
    }

    private var tile: some View {
        VStack(spacing: Theme.Spacing.xSmall) {
            icon
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isAvailable ? Theme.Colors.primaryText : Theme.Colors.tertiaryText)
        }
        .frame(width: 72)
    }

    private var icon: some View {
        ZStack {
            Image(nsImage: thumbnail ?? NSWorkspace.shared.icon(forFile: item.url.path(percentEncoded: false)))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .opacity(isAvailable ? 1 : 0.35)
            if !isAvailable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 48, height: 48)
    }

    private var accessibility: ShelfItemAccessibility {
        ShelfItemAccessibility(label: accessibilityLabel, url: item.url, isPinned: item.isPinned, actions: actions)
    }

    private var accessibilityLabel: String {
        var label = item.name
        if item.isPinned { label += ", pinned" }
        if !isAvailable { label += ", unavailable" }
        return label
    }

    private var actions: ShelfItemActions {
        ShelfItemActions(
            quickLook: { quickLook(item.url) },
            togglePin: { shelf.setPinned(item.id, !item.isPinned) },
            remove: { shelf.remove(item.id) },
            dragStarted: { model.hold(.dragging) },
            dragEnded: { model.release(.dragging) },
            menuOpened: { model.hold(.menu) },
            menuClosed: { model.release(.menu) }
        )
    }
}

enum ShelfActions {
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Puts the file on the clipboard so it can be pasted into Finder or another app without dragging.
    static func copy(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
    }

    /// The monochrome AirDrop glyph from Finder's sidebar. SF Symbols has no AirDrop symbol, so this falls back to a
    /// similar one if a future macOS moves the file.
    static let airDropGlyph: NSImage = {
        let path = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarAirDrop.icns"
        let image = NSImage(contentsOfFile: path)
            ?? NSImage(systemSymbolName: "dot.radiowaves.up.forward", accessibilityDescription: nil)
            ?? NSImage()
        image.isTemplate = true
        return image
    }()

    /// Opens the AirDrop window for the files. The app activates so the window comes to the front.
    static func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty,
              let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: urls)
        else { return }
        NSApp.activate()
        service.perform(withItems: urls)
    }

    static func thumbnail(for url: URL) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 44, height: 44),
            scale: 2,
            representationTypes: .thumbnail
        )
        let cgImage = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).cgImage
        return cgImage.map { NSImage(cgImage: $0, size: CGSize(width: 44, height: 44)) }
    }
}

/// Drop files here to AirDrop them, or click to AirDrop everything on the shelf. Files dropped here aren't added to the shelf.
private struct AirDropCard: View {
    let shelf: ShelfStore

    @State private var isTargeted = false

    private var shelfURLs: [URL] {
        shelf.sortedItems.filter(shelf.isAvailable).map(\.url)
    }

    var body: some View {
        let urls = shelfURLs
        Button {
            ShelfActions.airDrop(urls)
        } label: {
            VStack(spacing: Theme.Spacing.xSmall) {
                Image(nsImage: ShelfActions.airDropGlyph)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(isTargeted ? Theme.Colors.accent : Theme.Colors.secondaryText)
                Text("AirDrop")
                    .font(.system(size: 12, weight: .semibold))
                Text(isTargeted ? "Drop to send" : urls.isEmpty ? "Drop files here" : "Click to send shelf")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isTargeted ? Theme.Colors.accent : Theme.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Theme.Colors.cardBackground,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.Colors.accent, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: airDropDroppedFiles)
        .help(urls.isEmpty ? "Drop files to AirDrop them" : "AirDrop everything on the shelf, or drop files to AirDrop them")
        .accessibilityLabel(urls.isEmpty ? "AirDrop. Drop files here to send them." : "AirDrop shelf items")
    }

    private func airDropDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async {
                    if let url, url.isFileURL { urls.append(url) }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            ShelfActions.airDrop(urls)
        }
        return !providers.isEmpty
    }
}

/// The same actions as the item's menu, for VoiceOver.
private struct ShelfItemAccessibility: ViewModifier {
    let label: String
    let url: URL
    let isPinned: Bool
    let actions: ShelfItemActions

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Quick Look", actions.quickLook)
            .accessibilityAction(named: "Open") { ShelfActions.open(url) }
            .accessibilityAction(named: "Reveal in Finder") { ShelfActions.reveal(url) }
            .accessibilityAction(named: "Copy") { ShelfActions.copy(url) }
            .accessibilityAction(named: "AirDrop") { ShelfActions.airDrop([url]) }
            .accessibilityAction(named: isPinned ? "Unpin" : "Pin", actions.togglePin)
            .accessibilityAction(named: "Remove from Shelf", actions.remove)
    }
}

/// What a shelf item's menu and drag can do, supplied by the SwiftUI view.
private struct ShelfItemActions {
    var quickLook: () -> Void
    var togglePin: () -> Void
    var remove: () -> Void
    var dragStarted: () -> Void
    var dragEnded: () -> Void
    var menuOpened: () -> Void
    var menuClosed: () -> Void
}

/// Handles pointer interaction for a shelf item: drag to copy it elsewhere, click or right-click for a menu.
private struct ShelfItemInteraction: NSViewRepresentable {
    let url: URL
    let isAvailable: Bool
    let isPinned: Bool
    let actions: ShelfItemActions

    func makeNSView(context: Context) -> ShelfItemInteractionView {
        let view = ShelfItemInteractionView()
        update(view)
        return view
    }

    func updateNSView(_ view: ShelfItemInteractionView, context: Context) {
        update(view)
    }

    private func update(_ view: ShelfItemInteractionView) {
        view.url = url
        view.isAvailable = isAvailable
        view.isPinned = isPinned
        view.actions = actions
    }
}

private final class ShelfItemInteractionView: NSView, NSDraggingSource {
    var url: URL?
    var isAvailable = true
    var isPinned = false
    var actions: ShelfItemActions?

    private var mouseDownEvent: NSEvent?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownEvent, let url, isAvailable else { return }
        let start = mouseDownEvent.locationInWindow
        let current = event.locationInWindow
        guard hypot(current.x - start.x, current.y - start.y) > 3 else { return }
        self.mouseDownEvent = nil

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(bounds, contents: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
        actions?.dragStarted()
        beginDraggingSession(with: [item], event: mouseDownEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard mouseDownEvent != nil else { return }
        mouseDownEvent = nil
        showMenu(for: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        showMenu(for: event)
    }

    /// Copy only: dragging out of the shelf must never move or delete the original file.
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        actions?.dragEnded()
    }

    /// Shows the menu and waits for it to close. The notch is held open meanwhile so the menu keeps its anchor.
    private func showMenu(for event: NSEvent) {
        guard let actions else { return }
        actions.menuOpened()
        NSMenu.popUpContextMenu(makeMenu(actions), with: event, for: self)
        actions.menuClosed()
    }

    private func makeMenu(_ actions: ShelfItemActions) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        guard let url else { return menu }

        let fileItems = [
            ActionMenuItem.make(title: "Quick Look", handler: actions.quickLook),
            ActionMenuItem.make(title: "Open") { ShelfActions.open(url) },
            ActionMenuItem.make(title: "Reveal in Finder") { ShelfActions.reveal(url) },
            ActionMenuItem.make(title: "Copy") { ShelfActions.copy(url) },
            ActionMenuItem.make(title: "AirDrop") { ShelfActions.airDrop([url]) },
        ]
        for item in fileItems {
            item.isEnabled = isAvailable
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem.make(title: isPinned ? "Unpin" : "Pin to Shelf", handler: actions.togglePin))
        menu.addItem(ActionMenuItem.make(title: "Remove from Shelf", handler: actions.remove))
        return menu
    }
}
