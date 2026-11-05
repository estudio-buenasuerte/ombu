import SwiftUI

struct FolderGitLine: View {
    let status: GitStatus

    var body: some View {
        Text(status.branch + (status.isDirty ? " •" : ""))
            .font(PaletteFont.secondary())
            .tracking(PaletteFont.tracking)
            .foregroundStyle(Theme.text(0.5))
            .lineLimit(1)
    }
}
