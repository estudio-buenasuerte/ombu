import Foundation

/// What a terminal is running, as far as its shell integration says. Ghostty
/// sets the title to the command line as a command starts and back to the
/// working directory (or the shell's name) when it ends, so the first word of
/// each title is enough to recognise a known tool and to tell when it is gone.
///
/// Coding agents retitle their terminals constantly while they run, so an
/// unknown title keeps whatever was detected last rather than clearing it.
enum TabProcess: String, Hashable, CaseIterable {
    case claude, codex, opencode, gemini
    case editor, remote, git, runtime, container, monitor, build, reader

    /// The agents report themselves through their hooks, which is the surer
    /// signal; this is the fallback for a shell that typed the name.
    var isAgent: Bool {
        switch self {
        case .claude, .codex, .opencode, .gemini: true
        default: false
        }
    }

    /// A bundled brand image for agents, else an SF Symbol name.
    var symbol: Symbol {
        switch self {
        case .claude: .image("claude")
        case .codex: .image("codex")
        case .opencode: .image("opencode")
        case .gemini: .system("sparkle")
        case .editor: .system("square.and.pencil")
        case .remote: .system("network")
        case .git: .system("arrow.triangle.branch")
        case .runtime: .system("chevron.left.forwardslash.chevron.right")
        case .container: .system("shippingbox")
        case .monitor: .system("gauge.with.dots.needle.33percent")
        case .build: .system("hammer")
        case .reader: .system("doc.text")
        }
    }

    enum Symbol: Equatable {
        case image(String)
        case system(String)
    }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .opencode: "OpenCode"
        case .gemini: "Gemini"
        case .editor: "Editor"
        case .remote: "SSH"
        case .git: "Git"
        case .runtime: "REPL"
        case .container: "Containers"
        case .monitor: "Monitor"
        case .build: "Build"
        case .reader: "Viewer"
        }
    }

    private static let commands: [String: TabProcess] = [
        "claude": .claude, "codex": .codex, "opencode": .opencode, "gemini": .gemini,
        "vim": .editor, "nvim": .editor, "vi": .editor, "nano": .editor, "hx": .editor, "emacs": .editor, "micro": .editor,
        "ssh": .remote, "mosh": .remote, "et": .remote,
        "git": .git, "lazygit": .git, "tig": .git, "gh": .git,
        "node": .runtime, "bun": .runtime, "deno": .runtime, "python": .runtime, "python3": .runtime,
        "ipython": .runtime, "ruby": .runtime, "irb": .runtime, "swift": .runtime,
        "docker": .container, "podman": .container, "kubectl": .container, "k9s": .container,
        "top": .monitor, "htop": .monitor, "btop": .monitor, "btm": .monitor,
        "make": .build, "cargo": .build, "npm": .build, "pnpm": .build, "yarn": .build, "xcodebuild": .build, "go": .build, "zig": .build,
        "less": .reader, "man": .reader, "bat": .reader, "tail": .reader,
    ]

    /// Titles that mean the shell is back at its prompt: a shell's name, or
    /// a path in any of the shapes shell integration prints one.
    private static let shells: Set<String> = ["zsh", "bash", "fish", "sh", "dash", "ksh", "tcsh", "nu", "login"]

    /// The process after a title change. `current` is what was detected before.
    static func detect(after current: TabProcess?, title: String) -> TabProcess? {
        guard let first = title.split(separator: " ").first else { return current }
        let command = String(first).lowercased()
        let name = (command as NSString).lastPathComponent
        // Login shells write their name with a leading dash.
        let bare = name.hasPrefix("-") ? String(name.dropFirst()) : name
        if let match = commands[bare] { return match }
        if shells.contains(bare) || command.hasPrefix("~") || command.hasPrefix("/") || command.hasPrefix("…") { return nil }
        return current
    }
}
