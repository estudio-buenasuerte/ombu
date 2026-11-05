import Combine
import Foundation

@MainActor
final class FolderGitStatusModel: ObservableObject {
    @Published private(set) var revision = 0

    private let monitor = GitStatusMonitor()
    private var directories: Set<String> = []

    init() {
        monitor.onUpdate = { [weak self] in
            self?.revision += 1
        }
    }

    func watch(_ spaces: [SidebarSpace]) {
        let current = Set(spaces.flatMap(\.allFolders).compactMap { folder in
            folder.lastWorkingDirectory ?? folder.allSessions.first?.workingDirectory
        })
        guard current != directories else { return }
        directories = current
        monitor.watch(current.sorted())
        revision += 1
    }

    func status(for folder: TerminalFolder) -> GitStatus? {
        guard let directory = folder.lastWorkingDirectory ?? folder.allSessions.first?.workingDirectory else {
            return nil
        }
        return monitor.status(for: directory)
    }
}
