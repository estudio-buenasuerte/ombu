import AppKit
import Combine

@MainActor
final class ChromeFont: ObservableObject {
    static let shared = ChromeFont()

    @Published private(set) var family: String?

    var configURL: URL {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        } ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
        return base.appendingPathComponent("ombu/config", isDirectory: false)
    }

    private var watchers: [DispatchSourceFileSystemObject] = []
    private var activationObserver: AnyCancellable?

    private init() {
        reload()
        activationObserver = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.reload() }
            }
    }

    nonisolated static func parse(_ text: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let content = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            let parts = content.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            guard key == "font-family" else { continue }
            values[key] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        return values
    }

    func reload() {
        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let value = Self.parse(text)["font-family"]
        let nextFamily = value.flatMap { $0.isEmpty ? nil : $0 }
        if family != nextFamily {
            family = nextFamily
        }
        watchConfig()
    }

    private func watchConfig() {
        watchers.forEach { $0.cancel() }
        watchers.removeAll()

        // Watching an existing ancestor lets first-time config creation be noticed
        // without creating directories just to read a preference.
        var directory = configURL.deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: directory.path), directory.path != "/" {
            directory.deleteLastPathComponent()
        }
        watch(directory)

        // Editors can write in place or replace the file atomically; both must reload.
        watch(configURL)
    }

    private func watch(_ url: URL) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in self?.reload() }
        }
        source.setCancelHandler { close(descriptor) }
        watchers.append(source)
        source.resume()
    }
}
