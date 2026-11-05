import AppKit

/// The right side of the window: the selected tab's panes in a rounded card
/// set in from the frosted window, under a strip naming what the tab is
/// running and where. A workspace without tabs shows how to open one.
final class TerminalAreaViewController: NSViewController {
    /// Stays opaque even when the terminal is translucent, so split dividers
    /// never show the desktop through.
    var backgroundColor: NSColor {
        get { paneTreeView.backgroundColor }
        set { paneTreeView.backgroundColor = newValue }
    }
    /// The terminal's background at its opacity, behind the header and the
    /// empty state, so both read as part of the terminal rather than chrome.
    var surfaceFill: NSColor = .black {
        didSet {
            header.fill = surfaceFill
            emptyState.fill = surfaceFill
        }
    }
    var tabProcess: @MainActor (TerminalTab) -> TabProcess? = { _ in nil }
    let paneTreeView = PaneTreeView()
    private let card = CardView()
    private let header = PaneHeaderView()
    private let emptyState = EmptyStateView()
    private var workspace: Workspace?

    override func loadView() {
        let view = NSView()
        for child in [card, paneTreeView, header, emptyState] {
            child.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(card)
        card.content.addSubview(header)
        card.content.addSubview(paneTreeView)
        card.content.addSubview(emptyState)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.cardInset),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.cardInset),
            card.topAnchor.constraint(equalTo: view.topAnchor, constant: Theme.cardInset),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Theme.cardInset),
            header.leadingAnchor.constraint(equalTo: card.content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.content.trailingAnchor),
            header.topAnchor.constraint(equalTo: card.content.topAnchor),
            header.heightAnchor.constraint(equalToConstant: PaneHeaderView.height),
            paneTreeView.leadingAnchor.constraint(equalTo: card.content.leadingAnchor),
            paneTreeView.trailingAnchor.constraint(equalTo: card.content.trailingAnchor),
            paneTreeView.topAnchor.constraint(equalTo: header.bottomAnchor),
            paneTreeView.bottomAnchor.constraint(equalTo: card.content.bottomAnchor),
            emptyState.leadingAnchor.constraint(equalTo: card.content.leadingAnchor),
            emptyState.trailingAnchor.constraint(equalTo: card.content.trailingAnchor),
            emptyState.topAnchor.constraint(equalTo: card.content.topAnchor),
            emptyState.bottomAnchor.constraint(equalTo: card.content.bottomAnchor),
        ])
        self.view = view
    }

    func show(_ workspace: Workspace?) {
        self.workspace = workspace
        let tab = workspace?.selectedTab
        header.isHidden = tab == nil
        emptyState.isHidden = tab != nil
        if let tab {
            header.show(process: tabProcess(tab), surface: tab.focusedSurface, title: tab.title)
        }
        paneTreeView.show(tab?.panes)
        paneTreeView.updateDimming(focused: tab?.focusedSurface)
    }

    func focusSelectedSurface() {
        guard let surface = workspace?.selectedTab?.focusedSurface else { return }
        view.window?.makeFirstResponder(surface)
    }
}

/// A rounded, clipped container with a hairline and a soft shadow. The clip
/// and the shadow cannot share a layer, so the shadow is on this view and the
/// clip on `content`.
final class CardView: NSView {
    let content = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.22
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        content.wantsLayer = true
        content.layer?.masksToBounds = true
        content.layer?.cornerRadius = Theme.cardRadius
        content.layer?.cornerCurve = .continuous
        content.layer?.borderWidth = 1
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        layer?.shadowPath = CGPath(roundedRect: bounds, cornerWidth: Theme.cardRadius, cornerHeight: Theme.cardRadius, transform: nil)
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        content.layer?.borderColor = Theme.ink(0.10).cgColor(in: effectiveAppearance)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// A view painted in the terminal's own background, for the parts of the
/// card that are not a terminal.
class SurfaceFillView: NSView {
    var fill: NSColor = .black {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = fill.cgColor
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
    }
}

/// The strip above the panes: what the focused pane runs, its title and
/// where it is. It sits under the window's title bar, which only drags the
/// window there, so nothing in it needs clicking.
final class PaneHeaderView: SurfaceFillView {
    static let height: CGFloat = 32
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let path = NSTextField(labelWithString: "")
    private let hairline = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.contentTintColor = .secondaryLabelColor
        title.font = .systemFont(ofSize: 12.5, weight: .medium)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        path.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        path.textColor = .secondaryLabelColor
        path.lineBreakMode = .byTruncatingMiddle
        path.setContentCompressionResistancePriority(.defaultLow - 1, for: .horizontal)
        hairline.wantsLayer = true
        for child in [icon, title, path, hairline] {
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
        }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            path.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 10),
            path.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            path.centerYAnchor.constraint(equalTo: centerYAnchor),
            hairline.leadingAnchor.constraint(equalTo: leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: trailingAnchor),
            hairline.bottomAnchor.constraint(equalTo: bottomAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(process: TabProcess?, surface: TerminalSurfaceView, title name: String) {
        switch process?.symbol {
        case .image(let name)?:
            icon.image = NSImage(named: "Agents/\(name)")
        case .system(let name)?:
            icon.image = NSImage(systemSymbolName: name, accessibilityDescription: process?.displayName)
        case nil:
            icon.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Shell")
        }
        icon.symbolConfiguration = .init(pointSize: 11, weight: .medium)
        let directory = surface.workingDirectory?.abbreviatingHome
        title.stringValue = name
        // The shell names its prompt after the directory, in which case the
        // directory is already on show.
        path.stringValue = directory == name ? "" : directory ?? ""
    }

    override func updateLayer() {
        super.updateLayer()
        hairline.layer?.backgroundColor = Theme.ink(0.08).cgColor(in: effectiveAppearance)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// What a workspace with no tabs shows in place of a terminal.
final class EmptyStateView: SurfaceFillView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        let icon = NSImageView(image: NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)!)
        icon.symbolConfiguration = .init(pointSize: 34, weight: .regular)
        icon.contentTintColor = .tertiaryLabelColor
        let title = NSTextField(labelWithString: "No Tabs")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .secondaryLabelColor
        let hint = NSTextField(labelWithString: "Press ⌘T to open a new tab.")
        hint.font = .systemFont(ofSize: 13)
        hint.textColor = .tertiaryLabelColor
        let stack = NSStackView(views: [icon, title, hint])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.setCustomSpacing(14, after: icon)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
