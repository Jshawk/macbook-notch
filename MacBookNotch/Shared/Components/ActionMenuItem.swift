import AppKit

/// Builds menu items that run a closure.
enum ActionMenuItem {
    static func make(title: String, handler: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(MenuActionTarget.run(_:)), keyEquivalent: "")
        item.target = MenuActionTarget.shared
        item.representedObject = MenuAction(handler: handler)
        return item
    }
}

private final class MenuAction {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }
}

/// `NSMenuItem.target` is weak, so the items share one long-lived target.
private final class MenuActionTarget: NSObject {
    static let shared = MenuActionTarget()

    @objc func run(_ sender: NSMenuItem) {
        (sender.representedObject as? MenuAction)?.handler()
    }
}
