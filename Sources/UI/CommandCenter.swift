import Foundation

/// What ⌘T lists: a new tab first, then every tab in the window, then
/// Ombú's commands. A search finds a tab by its title, what it is running
/// or its workspace, and a command by its name.
enum CommandCenter {
    enum Section: String, CaseIterable {
        case suggestions = "Suggestions"
        case tabs = "Tabs"
        case commands = "Commands"
    }

    enum Command: CaseIterable, Equatable {
        case newWorkspace, splitRight, splitDown, closeTab, renameWorkspace, toggleSidebar, settings, reloadConfiguration, keyboardShortcuts

        var title: String {
            switch self {
            case .newWorkspace: "New Workspace"
            case .splitRight: "Split Right"
            case .splitDown: "Split Down"
            case .closeTab: "Close Tab"
            case .renameWorkspace: "Rename Workspace"
            case .toggleSidebar: "Toggle Sidebar"
            case .settings: "Settings"
            case .reloadConfiguration: "Reload Configuration"
            case .keyboardShortcuts: "Keyboard Shortcuts"
            }
        }

        var symbol: String {
            switch self {
            case .newWorkspace: "folder.badge.plus"
            case .splitRight: "rectangle.split.2x1"
            case .splitDown: "rectangle.split.1x2"
            case .closeTab: "xmark.square"
            case .renameWorkspace: "pencil"
            case .toggleSidebar: "sidebar.left"
            case .settings: "gearshape"
            case .reloadConfiguration: "arrow.clockwise"
            case .keyboardShortcuts: "keyboard"
            }
        }

        /// The keys, one per cap, as the Keyboard Shortcuts window lists them.
        var shortcut: [String] {
            switch self {
            case .newWorkspace: ["⌘", "N"]
            case .splitRight: ["⌘", "D"]
            case .splitDown: ["⇧", "⌘", "D"]
            case .closeTab: ["⌥", "⌘", "W"]
            case .renameWorkspace: ["⇧", "⌘", "R"]
            case .toggleSidebar: ["⌘", "B"]
            case .settings: ["⌘", ","]
            case .reloadConfiguration: ["⇧", "⌘", ","]
            case .keyboardShortcuts: []
            }
        }
    }

    enum Target: Equatable {
        case newTab
        case tab(UUID)
        case command(Command)
    }

    struct Entry: Equatable {
        var section: Section
        var target: Target
        var title: String
        /// Shown at the trailing edge: a tab's workspace.
        var detail: String = ""
        /// An SF Symbol, unless `image` names an asset.
        var symbol: String = "terminal"
        var image: String? = nil
        var shortcut: [String] = []
        /// What a search matches besides the title.
        var searchText: [String] = []
    }

    static let newTab = Entry(section: .suggestions, target: .newTab, title: "New Tab", symbol: "plus.square", shortcut: ["↩"])

    static func entries(in store: WorkspaceStore, process: (TerminalTab) -> TabProcess?) -> [Entry] {
        let tabs = store.workspaces.flatMap { workspace in
            workspace.tabs.map { tab -> Entry in
                let process = process(tab)
                var entry = Entry(section: .tabs, target: .tab(tab.focusedSurface.id), title: tab.title, detail: workspace.name)
                switch process?.symbol {
                case .image(let name)?: entry.image = name
                case .system(let name)?: entry.symbol = name
                case nil: break
                }
                entry.searchText = [workspace.name, tab.focusedSurface.workingDirectory?.abbreviatingHome, process?.displayName, process?.rawValue].compactMap { $0 }
                return entry
            }
        }
        let commands = Command.allCases.map {
            Entry(section: .commands, target: .command($0), title: $0.title, symbol: $0.symbol, shortcut: $0.shortcut)
        }
        return [newTab] + tabs + commands
    }

    /// The entries matching the query, best first within their sections,
    /// which keep their order. A title match outranks one in the search text.
    static func filter(_ entries: [Entry], query: String) -> [Entry] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return entries }
        return entries.enumerated()
            .compactMap { index, entry -> (entry: Entry, key: (Int, Int, Int))? in
                let score = CommandPalette.score(words, in: [entry.title]).map { $0 + 1000 }
                    ?? CommandPalette.score(words, in: [entry.title] + entry.searchText)
                guard let score else { return nil }
                return (entry, (Section.allCases.firstIndex(of: entry.section)!, -score, index))
            }
            .sorted { $0.key < $1.key }
            .map(\.entry)
    }
}
