import AppKit
import SwiftUI

/// The Settings window: a pane per toolbar button, like other Mac apps. Only
/// Ombú's own settings are here; the terminal is configured in Ghostty's
/// config file, which the Advanced pane opens.
final class SettingsWindowController: NSWindowController {
    private static let size = CGSize(width: 560, height: 420)

    /// `problems` reads the diagnostics of the config libghostty last loaded,
    /// and `reload` asks for it to be read again.
    init(problems: @escaping () -> [String], reload: @escaping () -> Void) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.pane("General", symbol: "gearshape", GeneralSettingsView()))
        tabs.addTabViewItem(Self.pane("Notifications", symbol: "bell.badge", NotificationsSettingsView()))
        tabs.addTabViewItem(Self.pane("Ghostty", symbol: "terminal", AdvancedSettingsView(problems: problems, reload: reload)))
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Every pane is the same size, so the window doesn't jump between tabs
    /// and a long pane scrolls instead of growing past the screen.
    private static func pane(_ title: String, symbol: String, _ view: some View) -> NSTabViewItem {
        let controller = NSHostingController(rootView: view.frame(width: size.width, height: size.height))
        controller.sizingOptions = .preferredContentSize
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }

    func show() {
        guard let window else { return }
        if !window.isVisible { window.center() }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
