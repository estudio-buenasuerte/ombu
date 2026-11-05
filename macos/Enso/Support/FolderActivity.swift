import Foundation

enum FolderActivity: Equatable {
    case working, waiting, done
}

extension TerminalSession {
    enum AttentionKind: Hashable {
        case needsInput, finishedResponding
    }
}

extension TerminalFolder {
    var activity: FolderActivity? {
        var result: FolderActivity?
        for session in allSessions {
            if session.status == .attention {
                if session.attentionKind == .needsInput { return .waiting }
                if result == nil { result = .done }
            } else if session.runningProcess != nil && !session.isSleeping {
                result = .working
            }
        }
        return result
    }

    /// A manually named folder must keep its title when its tabs change directory.
    mutating func nameIfDefault(forDirectory directory: String) {
        guard title.range(of: #"^Folder [0-9]+$"#, options: .regularExpression) != nil else { return }
        title = FolderNaming.name(forDirectory: directory)
    }

    /// An empty folder gains its project association as soon as a tab arrives.
    mutating func initializeWorkingDirectory(_ directory: String) {
        guard lastWorkingDirectory == nil else { return }
        lastWorkingDirectory = directory
        nameIfDefault(forDirectory: directory)
    }
}

enum FolderNaming {
    static func name(forDirectory directory: String) -> String {
        let directoryURL = URL(fileURLWithPath: (directory as NSString).expandingTildeInPath)
            .standardizedFileURL
        let homeURL = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL
        var current = directoryURL
        while true {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent(".git").path) {
                // A repository at home is usually dotfiles, not the tab's project.
                return current.path == homeURL.path ? directoryURL.lastPathComponent : current.lastPathComponent
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { return directoryURL.lastPathComponent }
            current = parent
        }
    }
}
