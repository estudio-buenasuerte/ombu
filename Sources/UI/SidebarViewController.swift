import AppKit

protocol SidebarViewControllerDelegate: AnyObject {
    func sidebar(_ sidebar: SidebarViewController, didSelect workspace: Workspace)
    func sidebar(_ sidebar: SidebarViewController, didSelect tab: TerminalTab, in workspace: Workspace)
    /// The name is nil when the rename was abandoned.
    func sidebar(_ sidebar: SidebarViewController, didFinishRenaming workspace: Workspace, to name: String?)
    func sidebar(_ sidebar: SidebarViewController, wantsClose workspace: Workspace)
    func sidebar(_ sidebar: SidebarViewController, wantsClose tab: TerminalTab, in workspace: Workspace)
    func sidebar(_ sidebar: SidebarViewController, wantsNewTabIn workspace: Workspace)
    func sidebarWantsNewTerminal(_ sidebar: SidebarViewController)
}

/// The list on the left of the window. Each workspace is a trunk: a row with
/// its name, directory and git branch, and under it a row for each of its
/// tabs, the branches, showing what each one is running and what its agent
/// is doing. A New Terminal row closes the list.
final class SidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    weak var delegate: SidebarViewControllerDelegate?
    /// The one dot for a group of terminals: a tab's panes, or a workspace's.
    var indicator: @MainActor ([UUID]) -> AgentIndicator? = { _ in nil }
    var tabProcess: @MainActor (TerminalTab) -> TabProcess? = { _ in nil }

    enum Row {
        case workspace(Workspace)
        case tab(Workspace, TerminalTab)
        case newTerminal

        var workspace: Workspace? {
            switch self {
            case .workspace(let workspace), .tab(let workspace, _): workspace
            case .newTerminal: nil
            }
        }

        var tab: TerminalTab? {
            if case .tab(_, let tab) = self { return tab }
            return nil
        }

        var isWorkspace: Bool {
            if case .workspace = self { return true }
            return false
        }

        func matches(_ other: Row) -> Bool {
            switch (self, other) {
            case (.workspace(let a), .workspace(let b)): a === b
            case (.tab(_, let a), .tab(_, let b)): a === b
            case (.newTerminal, .newTerminal): true
            default: false
            }
        }
    }

    private let store: WorkspaceStore
    private var rows: [Row] = []
    private let tableView = WorkspaceTableView()
    private let scrollView = NSScrollView()
    private static let workspacePasteboardType = NSPasteboard.PasteboardType("com.buenasuerte.ombu.workspace")
    private var draggingWorkspace: Workspace?
    private var isReloading = false
    private var hoveredRow = -1
    private let git = GitStatusMonitor()
    /// Its row is left alone by reloads, which would otherwise replace the
    /// cell and discard the name being typed.
    private var renaming: Workspace?

    init(store: WorkspaceStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let column = NSTableColumn(identifier: .init("row"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = .zero
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = true
        tableView.target = self
        tableView.action = #selector(selectClickedRow)
        tableView.registerForDraggedTypes([Self.workspacePasteboardType])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        tableView.setDraggingSourceOperationMask([], forLocal: false)
        git.onUpdate = { [weak self] in self?.reloadRows() }

        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        // A connected mouse switches the system to always-visible scrollers,
        // which would take width from the rows.
        scrollView.scrollerStyle = .overlay
        NotificationCenter.default.addObserver(self, selector: #selector(keepOverlayScroller), name: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil)
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 6, left: 0, bottom: 10, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        // Scrolling moves rows under a still pointer, so the hovered row is
        // worked out again from where the pointer is.
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(updateHoveredRow), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        tableView.onPointerMove = { [weak self] in self?.updateHoveredRow() }

        let container = NSView()
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view = container
    }

    /// A preview keeps watching the repositories it moved away from, as the
    /// palette puts them back when it closes.
    func reload(isPreview: Bool = false) {
        let directories = store.workspaces.compactMap(\.directory)
        if isPreview {
            git.include(directories)
        } else {
            git.watch(directories)
        }
        reloadRows()
    }

    /// A terminal changing directory can follow a `git init` or a deleted
    /// repository, so every directory's repository and name are looked up
    /// again on the next reload.
    func forgetRepositories() {
        git.forgetDirectories()
        store.workspaces.forEach { $0.invalidateDerivedNames() }
    }

    /// Titles change with every prompt, so rows are redrawn in place while
    /// the same workspaces and tabs are listed.
    func reloadRows() {
        let wasReloading = isReloading
        isReloading = true
        defer { isReloading = wasReloading }
        let latest = store.workspaces.flatMap { workspace in
            [Row.workspace(workspace)] + workspace.tabs.map { Row.tab(workspace, $0) }
        } + [.newTerminal]
        let sameRows = latest.count == rows.count && zip(latest, rows).allSatisfy { $0.matches($1) }
        rows = latest
        if sameRows, tableView.numberOfRows == rows.count {
            var indexes = IndexSet(0..<rows.count)
            if let renaming, let row = row(of: renaming) {
                indexes.remove(row)
            }
            tableView.reloadData(forRowIndexes: indexes, columnIndexes: [0])
            // Reloads arrive with every shell prompt. Animated height changes
            // overlap and leave cells taller than their rows, which then snap
            // back on the next full layout.
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                tableView.noteHeightOfRows(withIndexesChanged: indexes)
            }
        } else {
            // A full reload replaces every cell, so a rename in progress is
            // abandoned rather than saved half typed.
            for row in 0..<tableView.numberOfRows {
                (tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? WorkspaceCellView)?.cancelRenaming()
            }
            renaming = nil
            tableView.reloadData()
        }
        if let workspace = store.selected, let tab = workspace.selectedTab, let row = row(of: tab) {
            tableView.selectRowIndexes([row], byExtendingSelection: false)
        } else {
            tableView.deselectAll(nil)
        }
    }

    /// Agents change state far more often than rows need rebuilding, so only
    /// the dots are updated: the tab's and its workspace's.
    func updateAgentIndicator(for tab: TerminalTab) {
        if let row = row(of: tab), let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? TabCellView {
            cell.agentIndicator = indicator(tab.panes.surfaces.map(\.id))
        }
        guard let workspace = rows.first(where: { $0.tab === tab })?.workspace, let row = row(of: workspace),
              let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? WorkspaceCellView else { return }
        cell.agentIndicator = indicator(workspace.surfaces.map(\.id))
    }

    private func row(of workspace: Workspace) -> Int? {
        rows.firstIndex { $0.isWorkspace && $0.workspace === workspace }
    }

    private func row(of tab: TerminalTab) -> Int? {
        rows.firstIndex { $0.tab === tab }
    }

    private func row(at index: Int) -> Row? {
        rows.indices.contains(index) ? rows[index] : nil
    }

    private var clickedRow: Row? {
        row(at: tableView.clickedRow)
    }

    /// The table sends its action when a press ends without becoming a drag
    /// or a context menu, which is when a click means going somewhere.
    @objc private func selectClickedRow() {
        go(to: clickedRow)
    }

    private func go(to row: Row?) {
        switch row {
        case .workspace(let workspace):
            guard workspace !== store.selected else { return }
            delegate?.sidebar(self, didSelect: workspace)
        case .tab(let workspace, let tab):
            guard workspace !== store.selected || workspace.selectedTab !== tab else { return }
            delegate?.sidebar(self, didSelect: tab, in: workspace)
        case .newTerminal:
            delegate?.sidebarWantsNewTerminal(self)
        case nil:
            break
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        switch clickedRow {
        case .workspace:
            menu.addItem(withTitle: "New Tab", action: #selector(newTabInClickedWorkspace), keyEquivalent: "")
            menu.addItem(withTitle: "Rename Workspace", action: #selector(renameClickedWorkspace), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Close Workspace", action: #selector(closeClickedWorkspace), keyEquivalent: "")
        case .tab:
            menu.addItem(withTitle: "Close Tab", action: #selector(closeClickedTab), keyEquivalent: "")
        case .newTerminal, nil:
            break
        }
    }

    @objc private func newTabInClickedWorkspace() {
        guard let workspace = clickedRow?.workspace else { return }
        delegate?.sidebar(self, wantsNewTabIn: workspace)
    }

    @objc private func renameClickedWorkspace() {
        guard let workspace = clickedRow?.workspace else { return }
        beginRename(of: workspace)
    }

    @objc private func closeClickedWorkspace() {
        guard let workspace = clickedRow?.workspace else { return }
        delegate?.sidebar(self, wantsClose: workspace)
    }

    @objc private func closeClickedTab() {
        guard case .tab(let workspace, let tab)? = clickedRow else { return }
        delegate?.sidebar(self, wantsClose: tab, in: workspace)
    }

    func beginRename(of workspace: Workspace) {
        guard renaming == nil, let row = row(of: workspace) else { return }
        tableView.scrollRowToVisible(row)
        guard let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: true) as? WorkspaceCellView else { return }
        renaming = workspace
        cell.beginRenaming { [weak self] name in
            guard let self else { return }
            self.renaming = nil
            let exists = self.store.workspaces.contains { $0 === workspace }
            self.delegate?.sidebar(self, didFinishRenaming: workspace, to: name.isEmpty || !exists ? nil : name)
        }
    }

    @objc private func keepOverlayScroller() {
        scrollView.scrollerStyle = .overlay
    }

    /// One row at most shows its buttons: the row under the pointer.
    @objc private func updateHoveredRow() {
        let row = tableView.hoveredRow
        guard row != hoveredRow else { return }
        hoveredRow = row
        for visible in 0..<tableView.numberOfRows {
            (tableView.view(atColumn: 0, row: visible, makeIfNecessary: false) as? SidebarCellView)?.isHovered = visible == row
            (tableView.rowView(atRow: visible, makeIfNecessary: false) as? SidebarRowView)?.isHovered = visible == row
        }
    }

    // MARK: NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    /// Only workspaces are dragged, to reorder them.
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard self.row(at: row)?.isWorkspace == true else { return nil }
        let item = NSPasteboardItem()
        item.setData(Data(), forType: Self.workspacePasteboardType)
        return item
    }

    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession,
                   willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet) {
        draggingWorkspace = rowIndexes.first.flatMap { row(at: $0)?.workspace }
    }

    private func draggedWorkspace(_ info: NSDraggingInfo) -> Workspace? {
        guard let source = info.draggingSource as? NSTableView, source === tableView,
              let draggingWorkspace, store.workspaces.contains(where: { $0 === draggingWorkspace }) else { return nil }
        return draggingWorkspace
    }

    /// Where among the workspaces a drop above a row lands: after every
    /// workspace whose row comes before it, which puts a drop among a
    /// workspace's tabs after that workspace.
    private func workspaceInsertionIndex(forRow row: Int) -> Int {
        rows.prefix(row).filter(\.isWorkspace).count
    }

    /// The row the drop line is drawn above: the workspace at that index, or
    /// the New Terminal row after the last one.
    private func tableRow(forWorkspaceInsertionIndex index: Int) -> Int {
        guard index < store.workspaces.count else { return max(rows.count - 1, 0) }
        return row(of: store.workspaces[index]) ?? rows.count
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                   proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard draggedWorkspace(info) != nil, (0...rows.count).contains(row) else { return [] }
        var above = row
        if dropOperation == .on {
            guard rows.indices.contains(row) else { return [] }
            let pointer = tableView.convert(info.draggingLocation, from: nil)
            above = insertionIndex(forDropOn: row, pointerY: pointer.y, rowRect: tableView.rect(ofRow: row))
        }
        // Dropping a row back where it is stays allowed, as in Finder, and
        // leaves the order alone.
        tableView.setDropRow(tableRow(forWorkspaceInsertionIndex: workspaceInsertionIndex(forRow: above)), dropOperation: .above)
        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                   row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard dropOperation == .above, let workspace = draggedWorkspace(info) else { return false }
        return store.move(workspace, toInsertionIndex: workspaceInsertionIndex(forRow: row))
    }

    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession,
                   endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        draggingWorkspace = nil
        self.tableView.refreshPointer(at: screenPoint)
    }

    // MARK: NSTableViewDelegate

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let view = SidebarRowView()
        view.isHovered = row == hoveredRow
        if case .newTerminal? = self.row(at: row) {
            view.pillInsets = NewTerminalCellView.pillInsets
        }
        return view
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch self.row(at: row) {
        case .workspace: 46
        case .tab, nil: 28
        case .newTerminal: NewTerminalCellView.height
        }
    }

    private func gitStatus(for workspace: Workspace) -> GitStatus? {
        guard let directory = workspace.directory else { return nil }
        return git.status(for: directory)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch self.row(at: row) {
        case .workspace(let workspace):
            let identifier = NSUserInterfaceItemIdentifier("workspace")
            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? WorkspaceCellView ?? {
                let cell = WorkspaceCellView()
                cell.identifier = identifier
                return cell
            }()
            cell.titleLabel.stringValue = workspace.name
            cell.isCurrent = workspace === store.selected
            cell.show(directory: workspace.directory, git: gitStatus(for: workspace))
            cell.agentIndicator = indicator(workspace.surfaces.map(\.id))
            cell.isHovered = row == hoveredRow
            cell.onClose = { [weak self, weak workspace] in
                guard let self, let workspace, self.store.workspaces.contains(where: { $0 === workspace }) else { return }
                self.delegate?.sidebar(self, wantsClose: workspace)
            }
            cell.onNewTab = { [weak self, weak workspace] in
                guard let self, let workspace, self.store.workspaces.contains(where: { $0 === workspace }) else { return }
                self.delegate?.sidebar(self, wantsNewTabIn: workspace)
            }
            return cell
        case .tab(let workspace, let tab):
            let identifier = NSUserInterfaceItemIdentifier("tab")
            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? TabCellView ?? {
                let cell = TabCellView()
                cell.identifier = identifier
                return cell
            }()
            cell.titleLabel.stringValue = tab.title
            cell.isCurrent = workspace === store.selected && workspace.selectedTab === tab
            cell.process = tabProcess(tab)
            cell.agentIndicator = indicator(tab.panes.surfaces.map(\.id))
            cell.isHovered = row == hoveredRow
            cell.onClose = { [weak self, weak workspace, weak tab] in
                guard let self, let workspace, let tab, workspace.tabs.contains(where: { $0 === tab }) else { return }
                self.delegate?.sidebar(self, wantsClose: tab, in: workspace)
            }
            return cell
        case .newTerminal:
            let identifier = NSUserInterfaceItemIdentifier("newTerminal")
            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NewTerminalCellView ?? {
                let cell = NewTerminalCellView()
                cell.identifier = identifier
                return cell
            }()
            cell.isHovered = row == hoveredRow
            return cell
        case nil:
            return nil
        }
    }

    /// Mouse presses may become drags. Accessibility selection can proceed
    /// without waiting for a click action. The New Terminal row is a button,
    /// never a selection.
    func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
        guard !self.tableView.isHandlingMouseDown else { return tableView.selectedRowIndexes }
        if let proposed = proposedSelectionIndexes.first, case .newTerminal? = row(at: proposed) {
            return tableView.selectedRowIndexes
        }
        return proposedSelectionIndexes
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isReloading, !tableView.isHandlingMouseDown else { return }
        go(to: row(at: tableView.selectedRow))
    }
}

/// Tracks the pointer over the whole list rather than row by row, so the
/// hovered row stays right while rows scroll or are reused.
private final class WorkspaceTableView: NSTableView {
    var onPointerMove: (() -> Void)?
    private(set) var isHandlingMouseDown = false

    override func mouseDown(with event: NSEvent) {
        isHandlingMouseDown = true
        defer { isHandlingMouseDown = false }
        super.mouseDown(with: event)
    }

    func refreshPointer(at screenPoint: NSPoint) {
        pointer = window?.convertPoint(fromScreen: screenPoint)
        onPointerMove?()
    }

    private var pointer: NSPoint?
    private var pointerArea: NSTrackingArea?

    /// Clicking a row leaves the keyboard with the terminal, so typing and
    /// arrow keys go on reaching the shell instead of switching workspaces.
    override var acceptsFirstResponder: Bool { false }

    var hoveredRow: Int {
        guard let pointer else { return -1 }
        let point = convert(pointer, from: nil)
        return visibleRect.contains(point) ? row(at: point) : -1
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerArea { removeTrackingArea(pointerArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        pointerArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        pointer = event.locationInWindow
        onPointerMove?()
    }

    override func mouseMoved(with event: NSEvent) {
        pointer = event.locationInWindow
        onPointerMove?()
    }

    override func mouseExited(with event: NSEvent) {
        pointer = nil
        onPointerMove?()
    }
}

/// Selection and hover are drawn as a pill set in from the sidebar's edges,
/// never as a full-width bar.
private final class SidebarRowView: NSTableRowView {
    var isHovered = false {
        didSet { if isHovered != oldValue { needsDisplay = true } }
    }
    var pillInsets = NSEdgeInsets(top: 1, left: 8, bottom: 1, right: 8)

    private var pill: NSBezierPath {
        let rect = NSRect(x: bounds.minX + pillInsets.left, y: bounds.minY + pillInsets.top,
                          width: bounds.width - pillInsets.left - pillInsets.right,
                          height: bounds.height - pillInsets.top - pillInsets.bottom)
        return NSBezierPath(roundedRect: rect, xRadius: Theme.rowRadius, yRadius: Theme.rowRadius)
    }

    override func drawSelection(in dirtyRect: NSRect) {
        Theme.selection.setFill()
        pill.fill()
    }

    override func drawBackground(in dirtyRect: NSRect) {
        guard isHovered, !isSelected else { return }
        Theme.ink(0.06).setFill()
        pill.fill()
    }
}

/// What the cells share: the buttons that appear on hover.
private class SidebarCellView: NSTableCellView {
    var isHovered = false {
        didSet { updateHoverViews() }
    }

    func updateHoverViews() {}

    static func symbolButton(_ symbol: String, description: String, size: CGFloat) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: description)!, target: nil, action: nil)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.symbolConfiguration = .init(pointSize: size, weight: .semibold)
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = description
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }
}

private final class WorkspaceCellView: SidebarCellView, NSTextFieldDelegate {
    let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let closeButton = symbolButton("xmark", description: "Close workspace", size: 9)
    private let newTabButton = symbolButton("plus", description: "New tab", size: 10)
    private let agentDot = AgentDotView()
    private var onRename: ((String) -> Void)?
    private var nameBeforeRenaming = ""
    private var clickMonitor: Any?
    var onClose: (() -> Void)?
    var onNewTab: (() -> Void)?

    /// The dragged row shows what it is rather than what the pointer happens
    /// to reveal on it.
    override var draggingImageComponents: [NSDraggingImageComponent] {
        let wasHovered = isHovered
        isHovered = false
        layoutSubtreeIfNeeded()
        // Vector rather than bitmap, so it stays sharp on any display the
        // drag crosses.
        let snapshot = NSImage(data: dataWithPDF(inside: bounds))
        isHovered = wasHovered

        let appearance = effectiveAppearance
        let image = NSImage(size: bounds.size, flipped: false) { rect in
            appearance.performAsCurrentDrawingAppearance {
                let card = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: Theme.rowRadius, yRadius: Theme.rowRadius)
                NSColor.windowBackgroundColor.setFill()
                card.fill()
                NSColor.separatorColor.setStroke()
                card.lineWidth = 1
                card.stroke()
            }
            snapshot?.draw(in: rect)
            return true
        }
        let component = NSDraggingImageComponent(key: .icon)
        component.contents = image
        component.frame = bounds
        return [component]
    }

    init() {
        super.init(frame: .zero)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.delegate = self
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        detailLabel.lineBreakMode = .byTruncatingMiddle

        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        newTabButton.target = self
        newTabButton.action = #selector(newTabTapped)
        let buttons = NSStackView(views: [newTabButton, closeButton])
        buttons.orientation = .horizontal
        buttons.spacing = 2
        buttons.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttons)
        addSubview(agentDot)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: buttons.leadingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),
            detailLabel.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),
            buttons.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            buttons.centerYAnchor.constraint(equalTo: centerYAnchor),
            agentDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            agentDot.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
        ])
        updateHoverViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The selected workspace's name is full ink; the others step back.
    var isCurrent = false {
        didSet { titleLabel.textColor = isCurrent ? .labelColor : .labelColor.withAlphaComponent(0.72) }
    }

    /// The dot stands for every terminal in the workspace, at the end of its
    /// name as in Flow; the buttons take its place under the pointer.
    var agentIndicator: AgentIndicator? {
        get { agentDot.indicator }
        set {
            agentDot.indicator = newValue
            updateHoverViews()
        }
    }

    override func updateHoverViews() {
        closeButton.isHidden = !isHovered
        newTabButton.isHidden = !isHovered
        agentDot.isHidden = agentDot.indicator == nil || isHovered
    }

    func show(directory: String?, git: GitStatus?) {
        let branch = git.map { $0.isDirty ? "\($0.branch)*" : $0.branch }
        let path = directory?.abbreviatingHome
        detailLabel.stringValue = [branch, path].compactMap { $0 }.joined(separator: "  ·  ")
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func newTabTapped() {
        onNewTab?()
    }

    /// Return or a click anywhere outside the field keeps the new name and
    /// Escape restores the old one, as renaming works in Finder. The completion
    /// gets the new name, or an empty one when the rename was abandoned.
    func beginRenaming(_ completion: @escaping (String) -> Void) {
        onRename = completion
        nameBeforeRenaming = titleLabel.stringValue
        titleLabel.isEditable = true
        titleLabel.isBezeled = true
        titleLabel.bezelStyle = .roundedBezel
        titleLabel.drawsBackground = true
        titleLabel.textColor = .labelColor
        window?.makeFirstResponder(titleLabel)
        titleLabel.currentEditor()?.selectAll(nil)
        // Clicks on the title bar, the terminal or empty sidebar space do not
        // take keyboard focus, so on their own they would leave the field open.
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            let inField = event.window === window
                && titleLabel.bounds.contains(titleLabel.convert(event.locationInWindow, from: nil))
            if !inField { window?.makeFirstResponder(nil) }
            return event
        }
    }

    /// Abandons a rename without telling the sidebar, which is reloading.
    func cancelRenaming() {
        onRename = nil
        endRenaming(keepingName: false)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        let completion = onRename
        onRename = nil
        endRenaming(keepingName: false)
        completion?("")
        return true
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        let completion = onRename
        onRename = nil
        let name = titleLabel.stringValue.trimmingCharacters(in: .whitespaces)
        endRenaming(keepingName: true)
        completion?(name)
    }

    private func endRenaming(keepingName: Bool) {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        if titleLabel.currentEditor() != nil {
            titleLabel.abortEditing()
        }
        if !keepingName {
            titleLabel.stringValue = nameBeforeRenaming
        }
        titleLabel.isEditable = false
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        let current = isCurrent
        isCurrent = current
    }
}

/// A tab under its workspace: what it runs, its title, and its agent's dot.
private final class TabCellView: SidebarCellView {
    let titleLabel = NSTextField(labelWithString: "")
    private let icon = NSImageView()
    private let closeButton = symbolButton("xmark", description: "Close tab", size: 9)
    private let agentDot = AgentDotView()
    var onClose: (() -> Void)?

    init() {
        super.init(frame: .zero)
        titleLabel.font = .systemFont(ofSize: 12.5)
        titleLabel.lineBreakMode = .byTruncatingTail
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyUpOrDown
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        addSubview(titleLabel)
        addSubview(closeButton)
        addSubview(agentDot)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            agentDot.centerXAnchor.constraint(equalTo: closeButton.centerXAnchor),
            agentDot.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        process = nil
        isCurrent = false
        updateHoverViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var isCurrent = false {
        didSet {
            titleLabel.textColor = isCurrent ? .labelColor : .secondaryLabelColor
            icon.contentTintColor = isCurrent ? .labelColor : .secondaryLabelColor
        }
    }

    /// An idle shell shows the terminal glyph; a known tool its own.
    var process: TabProcess? {
        didSet {
            switch process?.symbol {
            case .image(let name)?:
                icon.image = NSImage(named: "Agents/\(name)")
            case .system(let name)?:
                icon.image = NSImage(systemSymbolName: name, accessibilityDescription: process?.displayName)
            case nil:
                icon.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Shell")
            }
            icon.symbolConfiguration = .init(pointSize: 11, weight: .medium)
        }
    }

    var agentIndicator: AgentIndicator? {
        get { agentDot.indicator }
        set {
            agentDot.indicator = newValue
            updateHoverViews()
        }
    }

    /// The dot and the close button share one spot at the end of the row;
    /// the close button wins under the pointer.
    override func updateHoverViews() {
        closeButton.isHidden = !isHovered
        agentDot.isHidden = agentDot.indicator == nil || isHovered
    }

    @objc private func closeTapped() {
        onClose?()
    }
}

/// The row that closes the list, under a hairline: a plus and "New Terminal".
private final class NewTerminalCellView: SidebarCellView {
    static let height: CGFloat = 44
    /// Room above the pill for the hairline and a gap.
    static let pillInsets = NSEdgeInsets(top: 10, left: 8, bottom: 2, right: 8)
    private let hairline = NSView()

    init() {
        super.init(frame: .zero)
        let icon = NSImageView(image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil)!)
        icon.symbolConfiguration = .init(pointSize: 11, weight: .medium)
        icon.contentTintColor = .secondaryLabelColor
        let label = NSTextField(labelWithString: "New Terminal")
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .secondaryLabelColor
        hairline.wantsLayer = true
        for child in [hairline, icon, label] {
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
        }
        let pill = Self.pillInsets
        NSLayoutConstraint.activate([
            hairline.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            hairline.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            hairline.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            hairline.heightAnchor.constraint(equalToConstant: 1),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor, constant: (pill.top - pill.bottom) / 2),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateHairline()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateHairline()
    }

    private func updateHairline() {
        hairline.layer?.backgroundColor = Theme.ink(0.10).cgColor(in: effectiveAppearance)
    }
}
