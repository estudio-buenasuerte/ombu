import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(Preferences.secureKeyboardEntry) private var secureKeyboardEntry = false

    var body: some View {
        Form {
            Section {
                Toggle("Secure keyboard entry", isOn: $secureKeyboardEntry)
            } footer: {
                Text("Blocks other apps from reading keystrokes typed into Ombú. Ghostty's own `macos-auto-secure-input` setting still turns it on at password prompts.")
                    .settingsFooter()
            }

            Section {
                LabeledContent("Shell, font, theme, keybinds") {
                    Text("Set in Ghostty's config")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Ombú reads ~/.config/ghostty/config, the same file Ghostty.app uses. Edit it from the Ghostty pane.")
                    .settingsFooter()
            }
        }
        .formStyle(.grouped)
    }
}

extension Text {
    func settingsFooter() -> some View {
        font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
    }
}
