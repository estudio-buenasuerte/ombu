import Foundation

typealias TerminalTab = TabModel<TerminalSurfaceView>
typealias Workspace = WorkspaceModel<TerminalSurfaceView>
typealias WorkspaceStore = WorkspaceStoreModel<TerminalSurfaceView>
typealias PaneTree = PaneTreeModel<TerminalSurfaceView>
typealias Pane = PaneNode<TerminalSurfaceView>

extension TerminalSurfaceView: PaneLeaf {}

extension TerminalTab {
    var focusedSurface: TerminalSurfaceView { focusedLeaf }

    /// What the tab shows it is running: the agent its hooks report, else an
    /// agent a pane's title named, else what the focused pane's title says.
    func process(runningAgent: String?) -> TabProcess? {
        runningAgent.flatMap(TabProcess.init(rawValue:))
            ?? panes.surfaces.lazy.compactMap(\.process).first { $0.isAgent }
            ?? focusedSurface.process
    }
}

extension Workspace {
    var surfaces: [TerminalSurfaceView] { tabs.flatMap(\.panes.surfaces) }
}

extension PaneTree {
    var surfaces: [TerminalSurfaceView] { leaves }
}

extension Pane {
    var surface: TerminalSurfaceView? { leaf }
    var surfaces: [TerminalSurfaceView] { leaves }
}
