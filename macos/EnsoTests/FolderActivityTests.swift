import Foundation
import Testing
@testable import Enso

@MainActor
struct FolderActivityTests {
    private func session(
        status: TerminalSession.Status = .running,
        attention: TerminalSession.AttentionKind? = nil,
        process: TabProcess? = nil,
        sleeping: Bool = false
    ) -> TerminalSession {
        var session = TerminalSession(title: "tab", workingDirectory: "/tmp", status: status, isSleeping: sleeping)
        session.attentionKind = attention
        session.runningProcess = process
        return session
    }

    @Test func idleAndSleepingTabsHaveNoActivity() {
        #expect(TerminalFolder(title: "empty").activity == nil)
        let folder = TerminalFolder(title: "idle", sessions: [
            session(), session(status: .idle), session(process: .claude, sleeping: true),
            session(attention: .needsInput)
        ])
        #expect(folder.activity == nil)
    }

    @Test func foregroundProcessContributesWorking() {
        let folder = TerminalFolder(title: "project", sessions: [session(status: .idle, process: .claude)])
        #expect(folder.activity == .working)
    }

    @Test func attentionOverridesTheSameTabsForegroundProcess() {
        #expect(TerminalFolder(title: "waiting", sessions: [
            session(status: .attention, attention: .needsInput, process: .claude)
        ]).activity == .waiting)
        #expect(TerminalFolder(title: "done", sessions: [
            session(status: .attention, attention: .finishedResponding, process: .claude)
        ]).activity == .done)
        #expect(TerminalFolder(title: "restored", sessions: [
            session(status: .attention, process: .claude)
        ]).activity == .done)
    }

    @Test func priorityIsIndependentOfSubtreeOrder() {
        let waiting = session(status: .attention, attention: .needsInput)
        let working = session(process: .codex)
        let done = session(status: .attention, attention: .finishedResponding)
        for sessions in [[waiting, working, done], [done, working, waiting], [working, waiting, done]] {
            let nested = TerminalFolder(title: "nested", sessions: Array(sessions.dropFirst()))
            let folder = TerminalFolder(title: "project", items: [.tab(sessions[0]), .folder(nested)])
            #expect(folder.activity == .waiting)
        }
        for sessions in [[done, working], [working, done]] {
            #expect(TerminalFolder(title: "project", sessions: sessions).activity == .working)
        }
    }

    @Test func attentionKindIsNotPersistedAndOldStateDecodesWithoutIt() throws {
        let original = session(status: .attention, attention: .needsInput, process: .claude)
        let data = try JSONEncoder().encode(original)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["attentionKind"] == nil)
        let decoded = try JSONDecoder().decode(TerminalSession.self, from: data)
        #expect(decoded.attentionKind == nil)
        #expect(decoded.runningProcess == nil)
        #expect(decoded.status == .attention)
        #expect(TerminalFolder(title: "restored", sessions: [decoded]).activity == .done)
    }

    @Test(arguments: [false, true])
    func selectionAcknowledgesFolderAttention(agentStillOpen: Bool) throws {
        let front = session()
        let back = session(process: agentStillOpen ? .claude : nil)
        let folder = TerminalFolder(title: "project", sessions: [front, back])
        let store = TerminalSessionStore(
            spaces: [SidebarSpace(name: "Main", pinnedFolders: [folder], lastSelection: front.id)],
            persistToDisk: false
        )
        store.selection = front.id
        store.handleAgentAttention(tabID: back.id, kind: .needsInput, isAppActive: true)
        #expect(store.activeSpace.pinnedFolders.first?.activity == .waiting)
        #expect(store.sessions.first { $0.id == back.id }?.attentionKind == .needsInput)

        store.handleAgentAttention(tabID: back.id, kind: .finishedResponding, isAppActive: true)
        #expect(store.activeSpace.pinnedFolders.first?.activity == .done)
        #expect(store.sessions.first { $0.id == back.id }?.attentionKind == .finishedResponding)

        store.selection = back.id
        let selected = try #require(store.selectedSession)
        #expect(selected.attentionKind == nil)
        #expect(store.activeSpace.pinnedFolders.first?.activity == (agentStillOpen ? .working : nil))
    }

    private func makeGitDir(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data("ref: refs/heads/main\n".utf8).write(to: url.appendingPathComponent("HEAD"))
    }

    private func withTemporaryDirectory(_ test: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EnsoFolderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try test(root)
    }

    @Test(arguments: [false, true])
    func namingFindsRepositoryDirectoriesAndWorktreeFiles(gitIsDirectory: Bool) throws {
        try withTemporaryDirectory { root in
            let repo = root.appendingPathComponent("project")
            let nested = repo.appendingPathComponent("Sources/Feature")
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            // Discovery wants a real git dir: one with a HEAD, reached directly
            // or through a worktree's "gitdir:" pointer file.
            let git = repo.appendingPathComponent(".git")
            if gitIsDirectory {
                try makeGitDir(at: git)
            } else {
                let worktreeGitDir = root.appendingPathComponent("worktree-gitdir")
                try makeGitDir(at: worktreeGitDir)
                try Data("gitdir: \(worktreeGitDir.path)".utf8).write(to: git)
            }
            #expect(FolderNaming.name(forDirectory: repo.path) == "project")
            #expect(FolderNaming.name(forDirectory: nested.path) == "project")

            try makeGitDir(at: nested.appendingPathComponent(".git"))
            #expect(FolderNaming.name(forDirectory: nested.path) == "Feature")
        }
    }

    @Test func namingFallsBackToDirectoryOutsideRepositories() throws {
        try withTemporaryDirectory { root in
            let directory = root.appendingPathComponent("standalone")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            #expect(FolderNaming.name(forDirectory: directory.path) == "standalone")
            #expect(FolderNaming.name(forDirectory: directory.path + "/") == "standalone")
        }
    }

    @Test func creatingFolderUsesFirstTabsDirectoryInSidebarOrder() throws {
        try withTemporaryDirectory { root in
            let repo = root.appendingPathComponent("project")
            let nested = repo.appendingPathComponent("Sources")
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            try makeGitDir(at: repo.appendingPathComponent(".git"))
            let first = TerminalSession(title: "first", workingDirectory: nested.path)
            let second = TerminalSession(title: "second", workingDirectory: root.path)
            let space = SidebarSpace(name: "Main", ephemeralSessions: [first, second])
            let store = TerminalSessionStore(spaces: [space], persistToDisk: false)
            store.createFolder(with: [second.id, first.id], inSpace: space.id)
            let folder = try #require(store.activeSpace.pinnedFolders.first)
            #expect(folder.title == "project")
            #expect(folder.lastWorkingDirectory == nested.path)
        }
    }

    @Test(arguments: [false, true])
    func emptyFolderNamesOnFirstCreatedOrMovedTab(moveTab: Bool) throws {
        try withTemporaryDirectory { root in
            let tab = TerminalSession(title: "tab", workingDirectory: root.path)
            let store = TerminalSessionStore(
                spaces: [SidebarSpace(name: "Main", ephemeralSessions: [tab])], persistToDisk: false
            )
            store.createFolder()
            let empty = try #require(store.activeSpace.pinnedFolders.first)
            #expect(empty.title == "Folder 1")
            #expect(empty.lastWorkingDirectory == nil)
            if moveTab {
                store.move([tab.id], toFolder: empty.id)
            } else {
                store.createSession(inFolder: empty.id, workingDirectory: root.path)
            }
            let folder = try #require(store.activeSpace.pinnedFolders.first)
            #expect(folder.title == root.lastPathComponent)
            #expect(folder.lastWorkingDirectory == root.path)
        }
    }

    @Test func customFolderTitleSurvivesFirstTabAndDirectoryChanges() throws {
        try withTemporaryDirectory { root in
            let folder = TerminalFolder(title: "My project")
            let store = TerminalSessionStore(
                spaces: [SidebarSpace(name: "Main", pinnedFolders: [folder])], persistToDisk: false
            )
            store.createSession(inFolder: folder.id, workingDirectory: root.path)
            let tab = try #require(store.selectedSession)
            store.updateWorkingDirectory(tab.id, to: root.appendingPathComponent("Sources").path)
            #expect(store.activeSpace.pinnedFolders.first?.title == "My project")
        }
    }
}
