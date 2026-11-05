import AppKit

/// The ⌘T panel: a search field over sectioned entries. Up and down move
/// through the entries, Return chooses one, Escape or a click outside
/// cancels. With nothing typed, Return opens a new tab.
final class CommandCenterView: NSView, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var onChoose: ((CommandCenter.Entry) -> Void)?
    var onCancel: (() -> Void)?

    private enum Row {
        case header(String)
        case entry(CommandCenter.Entry)
    }

    private static let entryHeight: CGFloat = 44
    private static let headerHeight: CGFloat = 34
    private static let maximumListHeight: CGFloat = 480

    private let entries: [CommandCenter.Entry]
    private var rows: [Row] = []
    private let field = NSTextField()
    private let message = NSTextField(labelWithString: "No matches")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let panel = CenterPanel()
    private var listHeight: NSLayoutConstraint!
    private var clickMonitor: Any?

    init(entries: [CommandCenter.Entry]) {
        self.entries = entries
        super.init(frame: .zero)

        field.placeholderString = "Search tabs, commands or processes"
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 20)
        field.delegate = self
        field.cell?.isScrollable = true
        field.cell?.wraps = false

        let column = NSTableColumn(identifier: .init("row"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = .zero
        tableView.refusesFirstResponder = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(chooseClicked)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 4, left: 0, bottom: 12, right: 0)

        let searchIcon = NSImageView(image: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)!)
        searchIcon.symbolConfiguration = .init(pointSize: 18, weight: .regular)
        searchIcon.contentTintColor = .secondaryLabelColor
        let divider = HairlineView()
        message.font = .systemFont(ofSize: 14)
        message.textColor = .secondaryLabelColor

        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)
        for view in [searchIcon, field, divider, scrollView, message] {
            view.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(view)
        }
        listHeight = scrollView.heightAnchor.constraint(equalToConstant: 0)
        listHeight.priority = .dragThatCannotResizeWindow
        let preferredWidth = panel.widthAnchor.constraint(equalToConstant: 720)
        preferredWidth.priority = .defaultHigh + 1
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.topAnchor.constraint(equalTo: topAnchor, constant: 120),
            preferredWidth,
            panel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -48),
            panel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -24),
            searchIcon.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 22),
            searchIcon.widthAnchor.constraint(equalToConstant: 22),
            searchIcon.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            field.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 12),
            field.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -22),
            field.topAnchor.constraint(equalTo: panel.topAnchor, constant: 20),
            divider.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            divider.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 20),
            divider.heightAnchor.constraint(equalToConstant: 1),
            scrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            listHeight,
            message.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            message.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
        update()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func focusField() {
        window?.makeFirstResponder(field)
    }

    func cancel() {
        onCancel?()
    }

    /// The panel covers the window's content but not its title bar, so a
    /// click there cancels as a click on the backdrop does.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, clickMonitor == nil else { return }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            if let self, event.window === window, !bounds.contains(convert(event.locationInWindow, from: nil)) {
                cancel()
            }
            return event
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        guard newWindow == nil, let clickMonitor else { return }
        NSEvent.removeMonitor(clickMonitor)
        self.clickMonitor = nil
    }

    /// The window behind dims so the panel reads as the one thing to use.
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.28).setFill()
        dirtyRect.fill()
    }

    override func mouseDown(with event: NSEvent) { cancel() }
    override func rightMouseDown(with event: NSEvent) { cancel() }
    override func otherMouseDown(with event: NSEvent) { cancel() }

    private func update() {
        let shown = CommandCenter.filter(entries, query: field.stringValue)
        rows = []
        for section in CommandCenter.Section.allCases {
            let inSection = shown.filter { $0.section == section }
            guard !inSection.isEmpty else { continue }
            rows.append(.header(section.rawValue))
            rows.append(contentsOf: inSection.map(Row.entry))
        }
        tableView.reloadData()
        message.isHidden = !rows.isEmpty
        let height = rows.reduce(CGFloat(0)) { total, row in
            if case .header = row { return total + Self.headerHeight }
            return total + Self.entryHeight
        }
        listHeight.constant = min(max(height + 16, 80), Self.maximumListHeight)
        if let first = rows.firstIndex(where: { if case .entry = $0 { return true } else { return false } }) {
            select(first)
        }
    }

    private func entry(at row: Int) -> CommandCenter.Entry? {
        guard rows.indices.contains(row), case .entry(let entry) = rows[row] else { return nil }
        return entry
    }

    /// Steps over headers and wraps around at either end.
    private func step(by offset: Int) {
        let selectable = rows.indices.filter { entry(at: $0) != nil }
        guard !selectable.isEmpty else { return }
        let position = selectable.firstIndex(of: tableView.selectedRow) ?? (offset > 0 ? -1 : 0)
        select(selectable[((position + offset) % selectable.count + selectable.count) % selectable.count])
    }

    private func select(_ row: Int) {
        tableView.selectRowIndexes([row], byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func choose(_ row: Int) {
        guard let entry = entry(at: row) else { return }
        onChoose?(entry)
    }

    @objc private func chooseClicked() {
        choose(tableView.clickedRow)
    }

    // MARK: NSTextFieldDelegate

    func controlTextDidChange(_ notification: Notification) {
        update()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.moveToBeginningOfDocument(_:)): step(by: -1)
        case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.moveToEndOfDocument(_:)): step(by: 1)
        case #selector(NSResponder.insertNewline(_:)): choose(tableView.selectedRow)
        case #selector(NSResponder.cancelOperation(_:)): cancel()
        default: return false
        }
        return true
    }

    // MARK: NSTableViewDataSource, NSTableViewDelegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if case .header = rows[row] { return Self.headerHeight }
        return Self.entryHeight
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch rows[row] {
        case .header(let title): CenterHeaderView(title: title)
        case .entry(let entry): CenterEntryView(entry: entry)
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        CenterRowView()
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        entry(at: row) != nil
    }
}

/// A near-black rounded panel with a hairline, casting a soft shadow.
private final class CenterPanel: NSView {
    private static let cornerRadius: CGFloat = 14

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.shadowOpacity = 0.45
        layer?.shadowRadius = 30
        layer?.shadowOffset = NSSize(width: 0, height: -10)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = Theme.dynamic(dark: NSColor(white: 0.05, alpha: 0.96), light: NSColor(white: 0.97, alpha: 0.97)).cgColor(in: effectiveAppearance)
        layer?.borderColor = Theme.ink(0.12).cgColor(in: effectiveAppearance)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        layer?.shadowPath = CGPath(roundedRect: bounds, cornerWidth: Self.cornerRadius, cornerHeight: Self.cornerRadius, transform: nil)
    }

    /// Clicks inside the panel stay in it rather than reaching the backdrop.
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
}

private final class HairlineView: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = Theme.ink(0.10).cgColor(in: effectiveAppearance)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// The selected entry sits in a pill set in from the panel's edges.
private final class CenterRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        Theme.ink(0.09).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 12, dy: 2), xRadius: 10, yRadius: 10).fill()
    }
}

private final class CenterHeaderView: NSTableCellView {
    init(title: String) {
        super.init(frame: .zero)
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

private final class CenterEntryView: NSTableCellView {
    init(entry: CommandCenter.Entry) {
        super.init(frame: .zero)
        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        if let image = entry.image {
            icon.image = NSImage(named: "Agents/\(image)")
        } else {
            icon.image = NSImage(systemSymbolName: entry.symbol, accessibilityDescription: nil)
            icon.symbolConfiguration = .init(pointSize: 15, weight: .regular)
            icon.contentTintColor = .labelColor
        }
        let title = NSTextField(labelWithString: entry.title)
        title.font = .systemFont(ofSize: 15)
        title.lineBreakMode = .byTruncatingTail
        let detail = NSTextField(labelWithString: entry.detail)
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let keys = NSStackView(views: entry.shortcut.map(KeyCapView.init))
        keys.spacing = 3
        // The slack between title and keys belongs to the detail, never to
        // the caps, which keep the size of their key.
        keys.setContentHuggingPriority(.required, for: .horizontal)
        detail.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for view in [icon, title, detail, keys] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.trailingAnchor.constraint(lessThanOrEqualTo: detail.leadingAnchor, constant: -12),
            detail.trailingAnchor.constraint(equalTo: keys.leadingAnchor, constant: entry.shortcut.isEmpty ? 0 : -12),
            detail.centerYAnchor.constraint(equalTo: centerYAnchor),
            keys.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -26),
            keys.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

/// One key of a shortcut, drawn as a small cap.
private final class KeyCapView: NSView {
    private let label: NSTextField

    init(key: String) {
        label = NSTextField(labelWithString: key)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 4
        setContentHuggingPriority(.required, for: .horizontal)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A plain view has no size of its own for a stack to hug, so the cap
    /// says it is as wide as its key plus a margin, and never wider.
    override var intrinsicContentSize: NSSize {
        NSSize(width: max(20, label.intrinsicContentSize.width + 10), height: 20)
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = Theme.ink(0.08).cgColor(in: effectiveAppearance)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
