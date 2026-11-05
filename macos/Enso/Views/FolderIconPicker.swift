import SwiftUI

/// Popover content for choosing a folder's icon. Smaller than the space
/// editor's picker: one scrolling list, symbols then emoji by category.
struct FolderIconPicker: View {
    let current: SidebarSpace.Icon
    let onPick: (SidebarSpace.Icon) -> Void

    @State private var query = ""
    @State private var shufflePop = false

    private let catalog = IconCatalog.shared

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                searchField
                shuffleButton
            }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 36), spacing: 4)],
                    spacing: 4,
                    pinnedViews: [.sectionHeaders]
                ) {
                    if tokens.isEmpty {
                        Section {
                            ForEach(symbolTiles) { symbolTile($0) }
                        } header: {
                            sectionHeader("Icons")
                        }
                        ForEach(catalog.emojiCategories, id: \.self) { category in
                            Section {
                                ForEach(catalog.emojiByCategory[category] ?? [], id: \.emoji) { emojiTile($0) }
                            } header: {
                                sectionHeader(category)
                            }
                        }
                    } else {
                        ForEach(symbolTiles.filter { matches($0.searchText) }) { symbolTile($0) }
                        ForEach(catalog.emoji.filter { matches($0.searchText) }, id: \.emoji) { emojiTile($0) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(10)
        .frame(width: 320, height: 360)
        .background(Theme.panel)
        .presentationBackground(Theme.panel)
    }

    // MARK: Pieces

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text(0.35))
            TextField("Search icons and emoji", text: $query)
                .textFieldStyle(.plain)
                .font(PaletteFont.secondary(.regular))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 9)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.ink.opacity(0.06))
        )
    }

    private var shuffleButton: some View {
        Button {
            shuffle()
        } label: {
            Image(systemName: "shuffle")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inverseInk.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.ink.opacity(0.94)))
                .scaleEffect(shufflePop ? 0.85 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: shufflePop)
        }
        .buttonStyle(.plain)
        .help("Shuffle icon")
        .accessibilityLabel("Shuffle icon")
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.text(0.4))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 2)
        .background(Theme.panel.opacity(0.92))
    }

    private func symbolTile(_ tile: IconTile) -> some View {
        tileButton(tile.icon, label: tile.id) {
            FolderIconView(icon: tile.icon, size: 22)
        }
    }

    private func emojiTile(_ entry: EmojiEntry) -> some View {
        tileButton(.emoji(entry.emoji), label: entry.description) {
            Text(entry.emoji).font(.system(size: 20))
        }
    }

    private func tileButton<Content: View>(
        _ icon: SidebarSpace.Icon,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            onPick(icon)
        } label: {
            content()
                .frame(width: 36, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor.opacity(icon == current ? 0.35 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Data

    /// The catalog's first tile is the dot stand-in; a folder never uses it.
    private var symbolTiles: [IconTile] {
        Array(catalog.iconTiles.dropFirst())
    }

    private var tokens: [String] {
        query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private func matches(_ text: String) -> Bool {
        tokens.allSatisfy { text.contains($0) }
    }

    private func shuffle() {
        shufflePop = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            shufflePop = false
        }
        guard let next = catalog.shuffleChoices.filter({ $0 != current }).randomElement() else { return }
        onPick(next)
    }
}
