import AppKit
import UniformTypeIdentifiers

/// Ghostty's own config is the source of truth for the terminal: Ombú loads
/// the same files Ghostty.app does and never writes to them. Its own settings
/// live in the user defaults.
enum ConfigFile {
    /// The file Ghostty reads first, which is where people keep their config.
    static var url: URL {
        configHome.appendingPathComponent("ghostty", isDirectory: true).appendingPathComponent("config")
    }

    private static var configHome: URL {
        ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config", isDirectory: true)
    }

    /// Opens the config file in the user's text editor. Ghostty itself makes
    /// the file on first launch, so a missing one is left to it.
    static func openInEditor() {
        let url = url
        guard FileManager.default.fileExists(atPath: url.path) else {
            NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
            return
        }
        // The file has no extension, so it is opened as plain text rather
        // than with whatever claims extensionless files.
        guard let editor = NSWorkspace.shared.urlForApplication(toOpen: .plainText) else {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
    }
}
