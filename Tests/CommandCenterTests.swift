import XCTest

final class CommandCenterTests: XCTestCase {
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
