import Foundation

enum FolderActivity: Equatable {
    case working, waiting, done
}

extension TerminalSession {
    enum AttentionKind: Hashable {
        case needsInput, finishedResponding
    }

    var activity: FolderActivity? {
        if status == .attention {
            return attentionKind == .needsInput ? .waiting : .done
        } else if agentBusy == true
            || (agentBusy == nil && runningProcess != nil && !isSleeping) {
            return .working
        }
        return nil
    }
}

extension TerminalFolder {
    var activity: FolderActivity? {
        var result: FolderActivity?
        for session in allSessions {
            switch session.activity {
            case .waiting:
                return .waiting
            case .done:
                if result == nil { result = .done }
            case .working:
                result = .working
            case nil:
                break
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
        // A repository at home is usually dotfiles, not the tab's project.
        if let repository = GitRepository(containing: directoryURL.path),
           repository.workTree != GitRepository.home {
            return URL(fileURLWithPath: repository.workTree).lastPathComponent
        }
        return directoryURL.lastPathComponent
    }
}
