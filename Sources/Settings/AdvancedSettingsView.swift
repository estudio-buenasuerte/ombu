import AppKit
import SwiftUI

/// Where Ghostty's config lives and what libghostty made of it.
struct AdvancedSettingsView: View {
    let problems: () -> [String]
    let reload: () -> Void
    @State private var current: [String] = []

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HStack {
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([ConfigFile.url])
                        }
                        Button("Open in Editor") {
                            ConfigFile.openInEditor()
                        }
                    }
                } label: {
                    Text("Ghostty config")
                    Text(ConfigFile.url.path.abbreviatingHome)
                        .textSelection(.enabled)
                        .truncationMode(.middle)
                }
            } footer: {
                Text("Fonts, themes, custom shaders, keybinds and every other Ghostty option come from this file. Ombú never writes to it.")
                    .settingsFooter()
            }

            Section("Problems") {
                LabeledContent {
                    Button("Reload Configuration") {
                        reload()
                        current = problems()
                    }
                } label: {
                    Text(current.isEmpty ? "No problems" : current.count == 1 ? "1 problem" : "\(current.count) problems")
                    Text("Reload after editing the file (⇧⌘,).")
                }
                ForEach(current, id: \.self) { problem in
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { current = problems() }
    }
}
