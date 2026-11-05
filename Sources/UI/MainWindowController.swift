import AppKit
import GhosttyKit

/// One window: workspace sidebar on the left, terminal area on the right.
final class MainWindowController: NSWindowController {
    let sidebar: SidebarViewController
    let terminalArea = TerminalAreaViewController()
    private let store: WorkspaceStore
    private let content: WindowContentViewController
    private(set) var commandPalette: CommandPaletteView?
    var agentIndicator: @MainActor (UUID) -> AgentIndicator? = { _ in nil }
    var onResetZoom: (() -> Void)?
    var onNewWorkspace: (() -> Void)?
    private let sidebarAccessory = NSTitlebarAccessoryViewController()
    private let zoomAccessory = NSTitlebarAccessoryViewController()
    private let resetZoomButton = NSButton(
        image: NSImage(systemSymbolName: "arrow.down.right.and.arrow.up.left", accessibilityDescription: "Reset zoom")!,
        target: nil,
        action: nil)

    /// Without a saved frame the window opens offset from the frontmost one.
    init(store: WorkspaceStore, frame: CGRect?) {
        self.store = store
        self.sidebar = SidebarViewController(store: store)

        self.content = WindowContentViewController(sidebar: sidebar, content: terminalArea)

        // The frost runs edge to edge, title bar included; the sidebar shows
        // where the user is, so the title bar shows nothing itself.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentViewController = content
        window.setContentSize(NSSize(width: 1100, height: 700))
        window.minSize = NSSize(width: 600, height: 400)
        window.isReleasedWhenClosed = false
        if let frame {
            window.setFrame(Session.Window.placing(frame, on: NSScreen.screens.map(\.visibleFrame)), display: false)
        } else if let front = NSApp.keyWindow ?? NSApp.mainWindow {
            window.setFrame(front.frame.offsetBy(dx: 24, dy: -24), display: false)
        } else {
            window.center()
        }

        super.init(window: window)

        resetZoomButton.target = self
        resetZoomButton.action = #selector(resetZoomTapped)
        resetZoomButton.isBordered = false
        resetZoomButton.toolTip = "Show all panes"
        resetZoomButton.isHidden = true
        zoomAccessory.view = Self.accessoryRow([resetZoomButton])
        zoomAccessory.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(zoomAccessory)

        // In the title bar rather than the sidebar, so the toggle is still
        // there to bring the sidebar back once it is collapsed.
        sidebarAccessory.view = Self.accessoryRow([
            titlebarButton(symbol: "sidebar.left", description: "Toggle sidebar", action: #selector(toggleWorkspaceSidebar)),
        ])
        sidebarAccessory.layoutAttribute = .leading
        window.addTitlebarAccessoryViewController(sidebarAccessory)
    }

    private func titlebarButton(symbol: String, description: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: description)!, target: self, action: action)
        button.isBordered = false
        button.toolTip = description
        button.contentTintColor = .secondaryLabelColor
        return button
    }

    /// A titlebar accessory view must keep a zero origin: AppKit raises when
    /// a screen change re-lays out the titlebar and Auto Layout re-centres the
    /// view from its fitting size. A plain frame-based row has no fitting size
    /// of its own, so only the buttons inside it move.
    private static func accessoryRow(_ buttons: [NSButton]) -> NSView {
        let buttonSize = NSSize(width: 32, height: 28)
        let row = NSView(frame: NSRect(x: 0, y: 0, width: buttonSize.width * CGFloat(buttons.count), height: buttonSize.height))
        for (index, button) in buttons.enumerated() {
            button.frame = NSRect(x: buttonSize.width * CGFloat(index), y: 0, width: buttonSize.width, height: buttonSize.height)
            button.autoresizingMask = [.minYMargin, .maxYMargin]
            row.addSubview(button)
        }
        return row
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Ghostty renders the terminal background with the configured opacity, but
    /// only a non-opaque window lets the desktop show through it.
    func applyAppearance(config: GhosttyConfig, app: ghostty_app_t) {
        guard let window else { return }
        window.appearance = config.windowAppearance
        terminalArea.backgroundColor = config.backgroundColor
        let dim = config.unfocusedSplitDimming
        terminalArea.paneTreeView.unfocusedFill = dim > 0.001 ? config.unfocusedSplitFill.withAlphaComponent(dim) : nil
        terminalArea.show(store.selected)
        if config.backgroundOpacity < 1 {
            window.isOpaque = false
            window.backgroundColor = .white.withAlphaComponent(0.001)
            // Applies the configured radius, so a reload with blur off clears it.
            ghostty_set_window_background_blur(app, Unmanaged.passUnretained(window).toOpaque())
        } else {
            window.isOpaque = true
            window.backgroundColor = config.backgroundColor
        }
    }

    /// Re-reads the store and updates the sidebar, tab strip, and window title.
    func refresh(isPreview: Bool = false) {
        sidebar.reload(isPreview: isPreview)
        terminalArea.show(store.selected)
        updateWindowTitle()
        // The accessory controller's own isHidden is not honored in the
        // unified titlebar, so the button itself is hidden.
        resetZoomButton.isHidden = store.selected?.selectedTab?.panes.zoomed == nil
    }

    func agentsDidChange(in workspace: Workspace, tab: TerminalTab) {
        sidebar.updateAgentIndicator(for: tab)
    }

    /// Every tab's row shows its title, whichever workspace it is in.
    func titleDidChange(of surface: TerminalSurfaceView) {
        sidebar.reloadRows()
        terminalArea.show(store.selected)
        updateWindowTitle()
    }

    private func updateWindowTitle() {
        let workspace = store.selected?.name ?? "Ombú"
        let tab = store.selected?.selectedTab?.title
        window?.title = tab.map { "\(workspace) — \($0)" } ?? workspace
    }

    /// A rename is typed into the workspace's row, so a hidden sidebar is
    /// brought back for it.
    func beginRename(of workspace: Workspace) {
        if content.isSidebarHidden {
            content.isSidebarHidden = false
            window?.layoutIfNeeded()
        }
        sidebar.beginRename(of: workspace)
    }

    /// Covers the whole window, so a click anywhere outside the palette cancels it.
    func showCommandPalette(_ palette: CommandPaletteView) {
        closeCommandPalette()
        commandPalette = palette
        palette.translatesAutoresizingMaskIntoConstraints = false
        content.view.addSubview(palette)
        NSLayoutConstraint.activate([
            palette.leadingAnchor.constraint(equalTo: content.view.leadingAnchor),
            palette.trailingAnchor.constraint(equalTo: content.view.trailingAnchor),
            palette.topAnchor.constraint(equalTo: content.view.topAnchor),
            palette.bottomAnchor.constraint(equalTo: content.view.bottomAnchor),
        ])
        palette.focusField()
    }

    func closeCommandPalette() {
        commandPalette?.removeFromSuperview()
        commandPalette = nil
    }

    private(set) var commandCenter: CommandCenterView?

    /// Covers the whole window, like the palette, so a click anywhere outside
    /// the panel cancels it.
    func showCommandCenter(_ center: CommandCenterView) {
        closeCommandCenter()
        commandCenter = center
        center.columnInset = content.sidebarInset
        center.translatesAutoresizingMaskIntoConstraints = false
        content.view.addSubview(center)
        NSLayoutConstraint.activate([
            center.leadingAnchor.constraint(equalTo: content.view.leadingAnchor),
            center.trailingAnchor.constraint(equalTo: content.view.trailingAnchor),
            center.topAnchor.constraint(equalTo: content.view.topAnchor),
            center.bottomAnchor.constraint(equalTo: content.view.bottomAnchor),
        ])
        center.focusField()
    }

    func closeCommandCenter() {
        commandCenter?.removeFromSuperview()
        commandCenter = nil
    }

    @objc func toggleWorkspaceSidebar(_ sender: Any?) {
        content.toggleSidebar()
    }

    @objc private func resetZoomTapped() {
        onResetZoom?()
    }
}
