import XCTest

final class WorkspaceTests: XCTestCase {
    func testCustomTabNameOverridesPaneTitlesUntilCleared() {
        let first = FakeLeaf("shell"), second = FakeLeaf("editor")
        let tab = TestTab(leaf: first)
        tab.panes.split(first, direction: .right, with: second)
        tab.customName = "Notes"
        XCTAssertEqual(tab.title, "Notes")
        tab.focus(second)
        second.title = "changed"
        XCTAssertEqual(tab.title, "Notes")
        tab.customName = nil
        XCTAssertEqual(tab.title, "changed")
    }

    func testMovingTabToAnotherWorkspaceAppendsAndSelectsItBeforeNotifying() {
        let store = TestStore()
        let source = store.addWorkspace()
        let neighbor = TestTab(leaf: FakeLeaf("neighbor"))
        let first = FakeLeaf("first"), focused = FakeLeaf("focused")
        let tab = TestTab(leaf: first)
        tab.panes.split(first, direction: .right, with: focused)
        tab.focus(focused)
        tab.panes.toggleZoom(focused)
        tab.customName = "Moving"
        source.add(neighbor)
        source.add(tab)
        let target = store.addWorkspace()
        let existing = TestTab(leaf: FakeLeaf("existing"))
        target.add(existing)
        store.select(source)
        var changes = 0
        store.onChange = {
            changes += 1
            XCTAssertEqual(source.tabs.map(\.id), [neighbor.id])
            XCTAssertTrue(source.selectedTab === neighbor)
            XCTAssertEqual(target.tabs.map(\.id), [existing.id, tab.id])
            XCTAssertTrue(store.selected === target)
            XCTAssertTrue(target.selectedTab === tab)
        }

        XCTAssertTrue(store.move(tab, to: target))
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(tab.focusedLeaf === focused)
        XCTAssertTrue(tab.panes.zoomed === focused)
        XCTAssertEqual(tab.title, "Moving")
        XCTAssertTrue(store.workspace(containing: first)?.0 === target)
        XCTAssertTrue(store.workspace(containing: focused)?.1 === tab)
    }

    func testMovingLastTabLeavesSourceEmptyWithItsDirectory() {
        let store = TestStore()
        let source = store.addWorkspace()
        let tab = TestTab(leaf: FakeLeaf(workingDirectory: "/project"))
        source.add(tab)
        let target = store.addWorkspace()
        store.select(source)

        XCTAssertTrue(store.move(tab, to: target))
        XCTAssertEqual(store.workspaces.map(\.id), [source.id, target.id])
        XCTAssertTrue(source.tabs.isEmpty)
        XCTAssertNil(source.selectedTab)
        XCTAssertEqual(source.directory, "/project")
        XCTAssertTrue(store.selected === target)
        XCTAssertTrue(target.selectedTab === tab)
    }

    func testInvalidAndSameWorkspaceTabMovesDoNotNotifyOrChangeSelection() {
        let store = TestStore()
        let source = store.addWorkspace()
        let tab = TestTab(leaf: FakeLeaf())
        source.add(tab)
        let target = store.addWorkspace()
        let foreign = WorkspaceModel<FakeLeaf>()
        let foreignTab = TestTab(leaf: FakeLeaf())
        foreign.add(foreignTab)
        var changes = 0
        store.onChange = { changes += 1 }

        XCTAssertTrue(store.move(tab, to: source))
        XCTAssertFalse(store.move(tab, to: foreign))
        XCTAssertFalse(store.move(foreignTab, to: target))
        XCTAssertEqual(changes, 0)
        XCTAssertEqual(source.tabs.map(\.id), [tab.id])
        XCTAssertTrue(target.tabs.isEmpty)
        XCTAssertEqual(foreign.tabs.map(\.id), [foreignTab.id])
        XCTAssertTrue(store.selected === target)
        store.remove(target)
        changes = 0
        XCTAssertFalse(store.move(tab, to: target))
        XCTAssertEqual(changes, 0)
        XCTAssertEqual(source.tabs.map(\.id), [tab.id])
    }

    func testClosingOtherTabsKeepsSelectedTabAndItsPanes() {
        let workspace = WorkspaceModel<FakeLeaf>()
        let tabs = (0..<3).map { _ in TestTab(leaf: FakeLeaf()) }
        tabs.forEach(workspace.add)
        let selected = tabs[1]
        let split = FakeLeaf()
        selected.panes.split(selected.focusedLeaf, direction: .right, with: split)
        selected.focus(split)
        workspace.select(selected)

        workspace.tabs(closing: .others, from: selected).forEach(workspace.remove)

        XCTAssertEqual(workspace.tabs.map(\.id), [selected.id])
        XCTAssertTrue(workspace.selectedTab === selected)
        XCTAssertTrue(selected.focusedLeaf === split)
        XCTAssertEqual(selected.panes.leaves.count, 2)
    }

    func testTabTitleUsesDirectoryUntilTheShellSetsATitle() {
        let leaf = FakeLeaf(workingDirectory: NSHomeDirectory() + "/Code/flow")
        let tab = TestTab(leaf: leaf)
        XCTAssertEqual(tab.title, "~/Code/flow")
        leaf.title = "Running tests"
        XCTAssertEqual(tab.title, "Running tests")
        leaf.title = ""
        leaf.workingDirectory = "/tmp"
        XCTAssertEqual(tab.title, "/tmp")
        leaf.workingDirectory = ""
        XCTAssertEqual(tab.title, "Terminal")
        leaf.workingDirectory = nil
        XCTAssertEqual(tab.title, "Terminal")
    }

    func testRemovingSelectedTabSelectsNeighbor() {
        let workspace = WorkspaceModel<FakeLeaf>()
        let tabs = (0..<3).map { _ in TestTab(leaf: FakeLeaf()) }
        tabs.forEach(workspace.add)
        workspace.select(tabs[1])

        workspace.remove(tabs[1])
        XCTAssertTrue(workspace.selectedTab === tabs[2])

        workspace.remove(tabs[2])
        XCTAssertTrue(workspace.selectedTab === tabs[0])

        workspace.remove(tabs[0])
        XCTAssertNil(workspace.selectedTab)
    }

    func testRemovingUnselectedTabKeepsSelection() {
        let workspace = WorkspaceModel<FakeLeaf>()
        let tabs = (0..<2).map { _ in TestTab(leaf: FakeLeaf()) }
        tabs.forEach(workspace.add)
        workspace.select(tabs[0])
        workspace.remove(tabs[1])
        XCTAssertTrue(workspace.selectedTab === tabs[0])
    }

    func testMovingTabsPreservesSelection() {
        let workspace = WorkspaceModel<FakeLeaf>()
        let tabs = (0..<4).map { _ in TestTab(leaf: FakeLeaf()) }
        tabs.forEach(workspace.add)
        workspace.select(tabs[1])

        XCTAssertTrue(workspace.move(tabs[1], toInsertionIndex: 4))
        XCTAssertEqual(workspace.tabs.map(\.id), [tabs[0], tabs[2], tabs[3], tabs[1]].map(\.id))
        XCTAssertTrue(workspace.selectedTab === tabs[1])

        XCTAssertTrue(workspace.move(tabs[3], toInsertionIndex: 0))
        XCTAssertEqual(workspace.tabs.map(\.id), [tabs[3], tabs[0], tabs[2], tabs[1]].map(\.id))
        XCTAssertTrue(workspace.selectedTab === tabs[1])

        XCTAssertTrue(workspace.move(tabs[0], toInsertionIndex: 3))
        XCTAssertEqual(workspace.tabs.map(\.id), [tabs[3], tabs[2], tabs[0], tabs[1]].map(\.id))
        XCTAssertTrue(workspace.selectedTab === tabs[1])
    }

    func testInvalidAndUnchangedTabMovesKeepOrderAndSelection() {
        let workspace = WorkspaceModel<FakeLeaf>()
        let first = TestTab(leaf: FakeLeaf())
        let second = TestTab(leaf: FakeLeaf())
        workspace.add(first)
        workspace.add(second)

        XCTAssertTrue(workspace.move(first, toInsertionIndex: 0))
        XCTAssertTrue(workspace.move(first, toInsertionIndex: 1))
        XCTAssertTrue(workspace.move(second, toInsertionIndex: 2))
        XCTAssertFalse(workspace.move(first, toInsertionIndex: -1))
        XCTAssertFalse(workspace.move(first, toInsertionIndex: 3))
        let other = WorkspaceModel<FakeLeaf>()
        let foreign = TestTab(leaf: FakeLeaf())
        other.add(foreign)
        XCTAssertFalse(workspace.move(foreign, toInsertionIndex: 0))
        XCTAssertEqual(workspace.tabs.map(\.id), [first.id, second.id])
        XCTAssertTrue(workspace.selectedTab === second)
        XCTAssertEqual(other.tabs.map(\.id), [foreign.id])

        workspace.remove(first)
        XCTAssertFalse(workspace.move(first, toInsertionIndex: 0))
        XCTAssertTrue(workspace.move(second, toInsertionIndex: 0))
        XCTAssertTrue(workspace.move(second, toInsertionIndex: 1))
        XCTAssertEqual(workspace.tabs.map(\.id), [second.id])
        XCTAssertTrue(workspace.selectedTab === second)

        workspace.remove(second)
        XCTAssertFalse(workspace.move(second, toInsertionIndex: 0))
        XCTAssertTrue(workspace.tabs.isEmpty)
        XCTAssertNil(workspace.selectedTab)
    }

    func testReorderedTabsRestoreFromFileWithSelectionAndContents() throws {
        let store = TestStore()
        let workspace = store.addWorkspace()
        let tabs = ["first", "second", "third"].map { TestTab(leaf: FakeLeaf(workingDirectory: "/" + $0)) }
        tabs.forEach(workspace.add)
        workspace.select(tabs[0])
        XCTAssertTrue(workspace.move(tabs[0], toInsertionIndex: 3))
        XCTAssertTrue(workspace.move(tabs[2], toInsertionIndex: 0))
        let expected = store.snapshot()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("session.json")
        XCTAssertTrue(Session(windows: [expected]).save(to: url))

        let loaded = try XCTUnwrap(Session.load(from: url))
        let restored = TestStore()
        restored.restore(loaded.windows[0]) { id, directory, _ in
            FakeLeaf(id: id, workingDirectory: directory)
        }
        let restoredWorkspace = try XCTUnwrap(restored.selected)
        XCTAssertEqual(restoredWorkspace.tabs.map(\.focusedLeaf.id), [tabs[2], tabs[1], tabs[0]].map(\.focusedLeaf.id))
        XCTAssertEqual(restoredWorkspace.selectedTab?.focusedLeaf.id, tabs[0].focusedLeaf.id)
        XCTAssertEqual(restored.snapshot(), expected)
    }

    func testRemovingBackgroundPaneKeepsFocus() {
        let a = FakeLeaf("a"), b = FakeLeaf("b"), c = FakeLeaf("c")
        let tab = TestTab(leaf: a)
        tab.panes.split(a, direction: .right, with: b)
        tab.panes.split(b, direction: .down, with: c)
        tab.focus(a)

        tab.removePane(c)

        XCTAssertTrue(tab.focusedLeaf === a)
        XCTAssertEqual(tab.panes.leaves.map(\.title), ["a", "b"])
    }

    func testRemovingFocusedPaneFocusesItsNeighbor() {
        let a = FakeLeaf("a"), b = FakeLeaf("b"), c = FakeLeaf("c")
        let tab = TestTab(leaf: a)
        tab.panes.split(a, direction: .right, with: b)
        tab.panes.split(b, direction: .down, with: c)
        tab.focus(c)

        tab.removePane(c)

        XCTAssertTrue(tab.focusedLeaf === b)
    }

    func testTabsClosedByEachMode() {
        let workspace = WorkspaceModel<FakeLeaf>()
        let tabs = ["a", "b", "c", "d"].map { TestTab(leaf: FakeLeaf($0)) }
        tabs.forEach(workspace.add)
        func titles(_ mode: TabCloseMode, from index: Int) -> [String] {
            workspace.tabs(closing: mode, from: tabs[index]).map(\.title)
        }

        XCTAssertEqual(titles(.this, from: 1), ["b"])
        XCTAssertEqual(titles(.others, from: 1), ["a", "c", "d"])
        XCTAssertEqual(titles(.right, from: 1), ["c", "d"])
        XCTAssertEqual(titles(.right, from: 3), [], "nothing to the right of the last tab")
        XCTAssertEqual(workspace.tabs(closing: .this, from: TestTab(leaf: FakeLeaf("elsewhere"))).count, 0)
    }

    func testShowingPlacesPutsBackSelectionsAndFocus() {
        let store = TestStore()
        let first = store.addWorkspace()
        let left = FakeLeaf(), right = FakeLeaf()
        let split = TestTab(leaf: left)
        split.panes.split(left, direction: .right, with: right)
        first.add(split)
        let other = TestTab(leaf: FakeLeaf())
        first.add(other)
        let second = store.addWorkspace()
        second.add(TestTab(leaf: FakeLeaf()))
        let places = store.places
        var changes = 0
        store.onChange = { changes += 1 }

        XCTAssertFalse(store.show(places))
        XCTAssertEqual(changes, 0, "nothing to put back")

        store.select(first)
        first.select(split)
        split.focus(right)
        changes = 0
        XCTAssertTrue(store.show(places))
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(store.selected === second)
        XCTAssertTrue(first.selectedTab === other)
        XCTAssertTrue(split.focusedLeaf === left)

        first.select(split)
        first.remove(other)
        store.show(places)
        XCTAssertTrue(first.selectedTab === split, "a closed tab is not selected again")
    }

    func testDerivedNameCacheFollowsDirectoryFocusAndTabChanges() {
        var lookups: [String] = []
        let workspace = WorkspaceModel<FakeLeaf>(resolveName: { path in
            lookups.append(path)
            return path.folderName
        })
        let first = FakeLeaf(workingDirectory: "/first")
        let second = FakeLeaf(workingDirectory: "/second")
        let tab = TestTab(leaf: first)
        tab.panes.split(first, direction: .right, with: second)
        workspace.add(tab)
        for _ in 0..<20 { XCTAssertEqual(workspace.name, "first") }
        XCTAssertEqual(lookups, ["/first"])
        tab.focus(second)
        XCTAssertEqual(workspace.name, "second")
        second.workingDirectory = "/changed"
        XCTAssertEqual(workspace.name, "changed")
        workspace.customName = "mine"
        second.workingDirectory = "/renamed"
        XCTAssertEqual(workspace.name, "mine")
        XCTAssertEqual(lookups, ["/first", "/second", "/changed"])
        workspace.customName = nil
        XCTAssertEqual(workspace.name, "renamed")
        let other = TestTab(leaf: FakeLeaf(workingDirectory: "/other"))
        workspace.add(other)
        XCTAssertEqual(workspace.name, "other")
        workspace.select(tab)
        XCTAssertEqual(workspace.name, "renamed")
        XCTAssertEqual(lookups, ["/first", "/second", "/changed", "/renamed", "/other"], "a directory already named")
        workspace.invalidateDerivedNames()
        XCTAssertEqual(workspace.name, "renamed")
        XCTAssertEqual(lookups, ["/first", "/second", "/changed", "/renamed", "/other", "/renamed"])
    }

    func testNameFollowsDirectoryUntilRenamed() {
        let workspace = WorkspaceModel<FakeLeaf>()
        XCTAssertEqual(workspace.name, "~")

        let leaf = FakeLeaf(workingDirectory: NSHomeDirectory() + "/Code/flow")
        workspace.add(TestTab(leaf: leaf))
        XCTAssertEqual(workspace.name, "flow")

        leaf.workingDirectory = "/tmp"
        XCTAssertEqual(workspace.name, "tmp")

        workspace.customName = "mine"
        leaf.workingDirectory = "/var"
        XCTAssertEqual(workspace.name, "mine")
    }

    func testNameIsTheRepositoryAnywhereInsideIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repository = root.appendingPathComponent("segment")
        try FileManager.default.createDirectory(at: repository.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repository.appendingPathComponent("src/lib"), withIntermediateDirectories: true)
        try Data("ref: refs/heads/main\n".utf8).write(to: repository.appendingPathComponent(".git/HEAD"))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        let leaf = FakeLeaf(workingDirectory: repository.path)
        let workspace = WorkspaceModel<FakeLeaf>()
        workspace.add(TestTab(leaf: leaf))
        XCTAssertEqual(workspace.name, "segment")

        leaf.workingDirectory = repository.appendingPathComponent("src/lib").path
        XCTAssertEqual(workspace.name, "segment")

        leaf.workingDirectory = root.path
        XCTAssertEqual(workspace.name, root.lastPathComponent, "outside the repository the folder names it")
    }

    func testARepositoryAtHomeNamesNothing() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Downloads/notes"), withIntermediateDirectories: true)
        try Data("ref: refs/heads/main\n".utf8).write(to: home.appendingPathComponent(".git/HEAD"))
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }
        let workTree = try XCTUnwrap(GitRepository(containing: home.path)).workTree

        XCTAssertEqual(WorkspaceModel<FakeLeaf>.name(forDirectory: home.appendingPathComponent("Downloads/notes").path, home: workTree), "notes")
        XCTAssertEqual(WorkspaceModel<FakeLeaf>.name(forDirectory: home.appendingPathComponent("Downloads/notes").path, home: nil), home.lastPathComponent,
                       "the same repository away from home names the workspace")
    }

    func testNewWorkspaceGoesRightAfterTheSelectedOne() {
        let store = TestStore()
        let first = store.addWorkspace()
        let second = store.addWorkspace()
        let third = store.addWorkspace()
        XCTAssertEqual(store.workspaces.map(\.id), [first, second, third].map(\.id), "each new one follows the one added before it")

        store.select(first)
        let fourth = store.addWorkspace()
        XCTAssertEqual(store.workspaces.map(\.id), [first, fourth, second, third].map(\.id))
        XCTAssertTrue(store.selected === fourth)
    }

    func testAdoptingWorkspaceAppendsAndSelectsItWithTabsAndPanesIntact() {
        let store = TestStore()
        let existing = store.addWorkspace()
        let workspace = WorkspaceModel<FakeLeaf>(customName: "Moving")
        let first = FakeLeaf("first"), focused = FakeLeaf("focused")
        let tab = TestTab(leaf: first)
        tab.panes.split(first, direction: .right, with: focused)
        tab.focus(focused)
        tab.panes.toggleZoom(focused)
        let other = TestTab(leaf: FakeLeaf("other"))
        workspace.add(tab)
        workspace.add(other)
        workspace.select(tab)
        var changes = 0
        store.onChange = {
            changes += 1
            XCTAssertEqual(store.workspaces.map(\.id), [existing.id, workspace.id])
            XCTAssertTrue(store.selected === workspace)
            XCTAssertTrue(workspace.selectedTab === tab)
        }

        store.adopt(workspace)

        XCTAssertEqual(changes, 1)
        XCTAssertTrue(store.workspaces.last === workspace)
        XCTAssertEqual(workspace.name, "Moving")
        XCTAssertTrue(workspace.tabs[0] === tab)
        XCTAssertTrue(workspace.tabs[1] === other)
        XCTAssertTrue(tab.focusedLeaf === focused)
        XCTAssertTrue(tab.panes.zoomed === focused)
        XCTAssertTrue(tab.panes.leaves[0] === first)
        XCTAssertTrue(tab.panes.leaves[1] === focused)
    }

    func testAdoptingBeforeRemovingKeepsTerminalsInDestinationDuringSourceChange() {
        let source = TestStore()
        let remaining = source.addWorkspace()
        let workspace = source.addWorkspace()
        let leaf = FakeLeaf()
        let tab = TestTab(leaf: leaf)
        workspace.add(tab)
        let destination = TestStore()
        var changes = 0
        source.onChange = {
            changes += 1
            XCTAssertEqual(source.workspaces.map(\.id), [remaining.id])
            XCTAssertTrue(source.selected === remaining)
            XCTAssertNil(source.workspace(containing: leaf))
            XCTAssertTrue(destination.workspace(containing: leaf)?.0 === workspace)
            XCTAssertTrue(destination.workspace(containing: leaf)?.1 === tab)
        }

        destination.adopt(workspace)
        source.remove(workspace)

        XCTAssertEqual(changes, 1)
        XCTAssertTrue(destination.selected === workspace)
        XCTAssertTrue(workspace.selectedTab === tab)
    }

    func testMovingOnlyWorkspaceToAnotherStoreLeavesSourceEmpty() {
        let source = TestStore()
        let workspace = source.addWorkspace()
        let tab = TestTab(leaf: FakeLeaf())
        workspace.add(tab)
        let destination = TestStore()

        destination.adopt(workspace)
        source.remove(workspace)

        XCTAssertTrue(source.workspaces.isEmpty)
        XCTAssertNil(source.selected)
        XCTAssertTrue(destination.workspaces.first === workspace)
        XCTAssertTrue(destination.selected === workspace)
        XCTAssertTrue(workspace.selectedTab === tab)
    }

    func testStoreRemovalSelection() {
        let store = TestStore()
        let first = store.addWorkspace()
        let second = store.addWorkspace()
        let third = store.addWorkspace()
        store.select(second)

        store.remove(second)
        XCTAssertTrue(store.selected === third)
        store.remove(third)
        XCTAssertTrue(store.selected === first)
        store.remove(first)
        XCTAssertNil(store.selected)
        XCTAssertTrue(store.workspaces.isEmpty)
    }

    func testStoreFindsWorkspaceContainingLeaf() {
        let store = TestStore()
        let first = store.addWorkspace()
        let second = store.addWorkspace()
        let leaf = FakeLeaf()
        let tab = TestTab(leaf: FakeLeaf())
        tab.panes.split(tab.panes.leaves[0], direction: .right, with: leaf)
        second.add(tab)
        first.add(TestTab(leaf: FakeLeaf()))

        let found = store.workspace(containing: leaf)
        XCTAssertTrue(found?.0 === second)
        XCTAssertTrue(found?.1 === tab)
        XCTAssertNil(store.workspace(containing: FakeLeaf()))
    }

    func testStoreFindsTheWorkspaceAndTabForAnUnselectedPane() {
        let store = TestStore()
        let workspace = store.addWorkspace()
        let tab = TestTab(leaf: FakeLeaf())
        let leaf = FakeLeaf()
        tab.panes.split(tab.panes.leaves[0], direction: .right, with: leaf)
        workspace.add(tab)
        workspace.add(TestTab(leaf: FakeLeaf()))
        store.addWorkspace().add(TestTab(leaf: FakeLeaf()))

        let found = store.workspace(containing: leaf)
        XCTAssertTrue(found?.0 === workspace)
        XCTAssertTrue(found?.1 === tab)
        XCTAssertNil(store.workspace(containing: FakeLeaf()))
    }

    func testStoreNotifiesOnChange() {
        let store = TestStore()
        var changes = 0
        store.onChange = { changes += 1 }
        let workspace = store.addWorkspace()
        store.select(workspace)
        store.notifyChanged()
        store.remove(workspace)
        XCTAssertEqual(changes, 4)
    }

    func testSelectingCurrentWorkspacePublishesItsNewlySelectedTab() {
        let store = TestStore()
        let workspace = store.addWorkspace()
        let first = TestTab(leaf: FakeLeaf())
        let second = TestTab(leaf: FakeLeaf())
        workspace.add(first)
        workspace.add(second)
        var published: TestTab?
        store.onChange = { published = store.selected?.selectedTab }

        workspace.select(first)
        store.select(workspace)

        XCTAssertTrue(published === first)
    }

    func testMovingWorkspacesPreservesSelectionAndNotifies() {
        let store = TestStore()
        let workspaces = (0..<4).map { _ in store.addWorkspace() }
        store.select(workspaces[1])
        var changes = 0
        store.onChange = { changes += 1 }

        XCTAssertTrue(store.move(workspaces[1], toInsertionIndex: 4))
        XCTAssertEqual(store.workspaces.map(\.id), [workspaces[0], workspaces[2], workspaces[3], workspaces[1]].map(\.id))
        XCTAssertTrue(store.selected === workspaces[1])

        XCTAssertTrue(store.move(workspaces[3], toInsertionIndex: 0))
        XCTAssertEqual(store.workspaces.map(\.id), [workspaces[3], workspaces[0], workspaces[2], workspaces[1]].map(\.id))
        XCTAssertTrue(store.selected === workspaces[1])

        XCTAssertTrue(store.move(workspaces[0], toInsertionIndex: 3))
        XCTAssertEqual(store.workspaces.map(\.id), [workspaces[3], workspaces[2], workspaces[0], workspaces[1]].map(\.id))
        XCTAssertEqual(changes, 3)
    }

    func testInvalidAndUnchangedMovesDoNotNotify() {
        let store = TestStore()
        let first = store.addWorkspace()
        let second = store.addWorkspace()
        var changes = 0
        store.onChange = { changes += 1 }

        XCTAssertTrue(store.move(first, toInsertionIndex: 0))
        XCTAssertTrue(store.move(first, toInsertionIndex: 1))
        XCTAssertTrue(store.move(second, toInsertionIndex: 2))
        XCTAssertFalse(store.move(first, toInsertionIndex: -1))
        XCTAssertFalse(store.move(first, toInsertionIndex: 3))
        XCTAssertFalse(store.move(WorkspaceModel<FakeLeaf>(), toInsertionIndex: 0))
        XCTAssertEqual(store.workspaces.map(\.id), [first.id, second.id])
        XCTAssertEqual(changes, 0)
        store.remove(first)
        changes = 0
        XCTAssertFalse(store.move(first, toInsertionIndex: 0))
        XCTAssertEqual(store.workspaces.map(\.id), [second.id])
        XCTAssertTrue(store.selected === second)
        XCTAssertEqual(changes, 0)
    }

    func testMoveObserversSeeFinalOrderAndPreservedSelection() {
        let store = TestStore()
        let workspaces = (0..<3).map { _ in store.addWorkspace() }
        store.select(workspaces[1])
        var observedOrders: [[UUID]] = []
        store.onChange = {
            observedOrders.append(store.workspaces.map(\.id))
            XCTAssertTrue(store.selected === workspaces[1])
        }

        XCTAssertTrue(store.move(workspaces[1], toInsertionIndex: 3))
        XCTAssertTrue(store.move(workspaces[2], toInsertionIndex: 0))
        XCTAssertEqual(observedOrders, [
            [workspaces[0].id, workspaces[2].id, workspaces[1].id],
            [workspaces[2].id, workspaces[0].id, workspaces[1].id],
        ])
    }
}
