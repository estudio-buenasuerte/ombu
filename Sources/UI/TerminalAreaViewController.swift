import AppKit

/// The right side of the window: the selected tab's panes, in a rounded card
/// set in from the frosted window, as a floating sheet of terminal.
final class TerminalAreaViewController: NSViewController {
    /// Stays opaque even when the terminal is translucent, so split dividers
    /// never show the desktop through.
    var backgroundColor: NSColor {
        get { paneTreeView.backgroundColor }
        set { paneTreeView.backgroundColor = newValue }
    }
    let paneTreeView = PaneTreeView()
    private let card = CardView()
    private var workspace: Workspace?

    override func loadView() {
        let view = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        paneTreeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        card.content.addSubview(paneTreeView)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.cardInset),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.cardInset),
            card.topAnchor.constraint(equalTo: view.topAnchor, constant: Theme.cardInset),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Theme.cardInset),
            paneTreeView.leadingAnchor.constraint(equalTo: card.content.leadingAnchor),
            paneTreeView.trailingAnchor.constraint(equalTo: card.content.trailingAnchor),
            paneTreeView.topAnchor.constraint(equalTo: card.content.topAnchor),
            paneTreeView.bottomAnchor.constraint(equalTo: card.content.bottomAnchor),
        ])
        self.view = view
    }

    func show(_ workspace: Workspace?) {
        self.workspace = workspace
        paneTreeView.show(workspace?.selectedTab?.panes)
        paneTreeView.updateDimming(focused: workspace?.selectedTab?.focusedSurface)
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
