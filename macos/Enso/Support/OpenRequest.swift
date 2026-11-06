import Foundation

enum OpenRequest: Equatable {
    case directory(String)
    case command(directory: String, input: String)

    static func parse(_ url: URL, fileManager: FileManager = .default) -> OpenRequest? {
        if url.scheme?.lowercased() == "ssh" {
            guard let host = url.host?.removingPercentEncoding, !host.isEmpty else { return nil }
            var command = "ssh"
            if let port = url.port {
                command += " -p \(port)"
            }
            if let user = url.user?.removingPercentEncoding {
                command += " \(sshArgument(user))@\(sshArgument(host))"
            } else {
                command += " \(sshArgument(host))"
            }
            return .command(directory: NSHomeDirectory(), input: command + "\n")
        }

        guard url.isFileURL else { return nil }
        let path = url.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return nil }
        if isDirectory.boolValue {
            return .directory(path)
        }
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              attributes[.type] as? FileAttributeType == .typeRegular else { return nil }

        let parent = (path as NSString).deletingLastPathComponent
        let isExecutable = fileManager.isExecutableFile(atPath: path)
        let scriptExtensions = ["command", "sh", "tool", "zsh", "bash"]
        if isExecutable || scriptExtensions.contains((path as NSString).pathExtension) {
            let command = (isExecutable ? "" : "sh ") + "'\(singleQuoteEscaped(path))'\n"
            return .command(directory: parent, input: command)
        }
        return .directory(parent)
    }

    private static func singleQuoteEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\\''")
    }

    private static func sshArgument(_ value: String) -> String {
        let safeCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._@%+-")
        if value.unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) {
            return value
        }
        return "'\(singleQuoteEscaped(value))'"
    }
}
