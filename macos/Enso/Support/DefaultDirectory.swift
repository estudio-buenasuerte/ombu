import Foundation

enum DefaultDirectory {
    /// Ghostty's config file, under $XDG_CONFIG_HOME or ~/.config.
    static func ghosttyConfigURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        let base = environment["XDG_CONFIG_HOME"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        } ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
        return base.appendingPathComponent("ghostty/config", isDirectory: false)
    }

    /// The `working-directory` value of a Ghostty config text, expanded, or nil when it names home/inherit or is absent.
    nonisolated static func parse(_ text: String, home: String = NSHomeDirectory()) -> String? {
        var directory: String?
        for line in text.components(separatedBy: .newlines) {
            let content = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            let parts = content.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            guard key == "working-directory" else { continue }
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            switch value {
            case "", "home", "inherit": directory = nil
            case "~": directory = home
            default: directory = value.hasPrefix("~/") ? home + String(value.dropFirst()) : value
            }
        }
        return directory
    }

    /// The folder a launch tab opens in: the parsed value when it is an existing directory, else home.
    static func resolve(fileManager: FileManager = .default) -> String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        guard let text = try? String(contentsOf: ghosttyConfigURL(), encoding: .utf8),
              let directory = parse(text, home: home) else { return home }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory, isDirectory: &isDirectory),
              isDirectory.boolValue else { return home }
        return directory
    }
}
