import SwiftUI

extension TerminalFolder {
    /// Built once: the catalog's shuffle set is ~2,000 entries and every
    /// folder row asks for its icon on each render.
    private static let fallbackChoices = IconCatalog.shared.shuffleChoices

    /// The picked icon, or a stable pseudo-random one. Derived from the id's
    /// bytes because `hashValue` is reseeded every launch, which would
    /// reshuffle every folder's icon on each relaunch.
    var displayIcon: SidebarSpace.Icon {
        if let icon { return icon }
        let choices = Self.fallbackChoices
        guard !choices.isEmpty else { return .symbol("folder.fill") }
        let seed = withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        }
        return choices[Int(seed % UInt64(choices.count))]
    }
}

/// A folder's mark, sized like the space icon but quieter: symbols sit at the
/// ink tone of the folder glyph they replace.
struct FolderIconView: View {
    let icon: SidebarSpace.Icon
    var size: CGFloat = 16

    var body: some View {
        switch icon {
        case .dot:
            Circle()
                .fill(Theme.ink.opacity(0.6))
                .frame(width: size * 0.36, height: size * 0.36)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.61, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(0.6))
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: size * 0.67))
        }
    }
}
