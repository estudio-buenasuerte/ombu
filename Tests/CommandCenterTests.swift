import AppKit
import GhosttyKit
import XCTest

final class CommandCenterTests: XCTestCase {
    @MainActor
    func testTabCommandsAndMoveDestinationsFollowSelectedWorkspace() throws {
        _ = NSApplication.shared
        XCTAssertEqual(ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv), GHOSTTY_SUCCESS)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = directory.appendingPathComponent("config")
        try "shell-integration = none\n".write(to: config, atomically: true, encoding: .utf8)
        let runtime = try GhosttyRuntime(configFile: config)
        let store = WorkspaceStore()
        let tabCommands: [CommandCenter.Command] = [.renameTab, .duplicateTab, .closeOtherTabs, .copyWorkingDirectory, .openInFinder]
        let targets = tabCommands.map { CommandCenter.Target.command($0) }
        XCTAssertFalse(CommandCenter.entries(in: store, process: { _ in nil }).contains { targets.contains($0.target) })
        let source = store.addWorkspace(customName: "source")
        let other = store.addWorkspace(customName: "other")
        let empty = store.addWorkspace(customName: "empty")
        let surface = TerminalSurfaceView(runtime: runtime, configuration: .init(workingDirectory: "/source"), startImmediately: false)
        let tab = TerminalTab(leaf: surface)
        tab.customName = "Custom name"
        source.add(tab)
        store.select(source)

        let entries = CommandCenter.entries(in: store, process: { _ in .claude })
        XCTAssertEqual(entries.filter { targets.contains($0.target) }.map(\.title),
                       ["Rename Tab", "Duplicate Tab", "Close Other Tabs", "Copy Working Directory", "Open in Finder"])
        XCTAssertTrue(entries.filter { targets.contains($0.target) }.allSatisfy { $0.section == .commands && $0.shortcut.isEmpty })
        let moves = entries.filter { if case .moveTab = $0.target { return true }; return false }
        XCTAssertEqual(moves.map(\.title), ["Move Tab to other", "Move Tab to empty"])
        XCTAssertEqual(moves.map(\.target), [.moveTab(to: other.id), .moveTab(to: empty.id)])
        XCTAssertTrue(moves.allSatisfy { $0.section == .commands })
        XCTAssertEqual(CommandCenter.filter(entries, query: "move empty"), [moves[1]])
        XCTAssertEqual(entries.filter { $0.section == .tabs }.map(\.title), ["Custom name"])
        XCTAssertEqual(CommandCenter.filter(entries, query: "claude").map(\.target), [.tab(surface.id)])

        store.select(empty)
        let withoutTab = CommandCenter.entries(in: store, process: { _ in nil })
        XCTAssertFalse(withoutTab.contains { targets.contains($0.target) })
        XCTAssertFalse(withoutTab.contains { if case .moveTab = $0.target { return true }; return false })
        XCTAssertEqual(withoutTab.filter { $0.section == .tabs }.map(\.title), ["Custom name"])
        XCTAssertTrue(withoutTab.contains { $0.target == .command(.newWorkspace) })

        store.select(source)
        store.remove(other)
        store.remove(empty)
        let onlyWorkspace = CommandCenter.entries(in: store, process: { _ in nil })
        XCTAssertEqual(onlyWorkspace.filter { targets.contains($0.target) }.count, 5)
        XCTAssertFalse(onlyWorkspace.contains { if case .moveTab = $0.target { return true }; return false })
    }

    private func tab(_ title: String, workspace: String, process: String? = nil) -> CommandCenter.Entry {
        CommandCenter.Entry(section: .tabs, target: .tab(UUID()), title: title, detail: workspace,
                            searchText: [workspace] + (process.map { [$0] } ?? []))
    }

    private var entries: [CommandCenter.Entry] {
        [CommandCenter.newTab,
         tab("~/Code/ombu", workspace: "ombu", process: "Claude"),
         tab("vim notes.md", workspace: "notes"),
         CommandCenter.Entry(section: .commands, target: .command(.settings), title: "Settings"),
         CommandCenter.Entry(section: .commands, target: .command(.newWorkspace), title: "New Workspace")]
    }

    func testNoQueryListsEverythingInOrder() {
        XCTAssertEqual(CommandCenter.filter(entries, query: "").map(\.title),
                       ["New Tab", "~/Code/ombu", "vim notes.md", "Settings", "New Workspace"])
    }

    func testSectionsKeepTheirOrderAndTitlesOutrankSearchText() {
        // "new" is in two titles across sections; "ombu" only in a tab's title and workspace.
        XCTAssertEqual(CommandCenter.filter(entries, query: "new").map(\.title), ["New Tab", "New Workspace"])
        XCTAssertEqual(CommandCenter.filter(entries, query: "ombu").map(\.title), ["~/Code/ombu"])
    }

    func testFindsATabByWhatItRunsOrWhereItIs() {
        XCTAssertEqual(CommandCenter.filter(entries, query: "claude").map(\.title), ["~/Code/ombu"])
        XCTAssertEqual(CommandCenter.filter(entries, query: "notes").map(\.title), ["vim notes.md"])
        XCTAssertEqual(CommandCenter.filter(entries, query: "zzz"), [])
    }
}
