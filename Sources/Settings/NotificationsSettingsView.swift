import AppKit
import SwiftUI

struct NotificationsSettingsView: View {
    @AppStorage(Preferences.needsInputNotification) private var needsInputNotification = true
    @AppStorage(Preferences.needsInputSound) private var needsInputSound = ""
    @AppStorage(Preferences.finishedNotification) private var finishedNotification = true
    @AppStorage(Preferences.finishedSound) private var finishedSound = ""

    var body: some View {
        Form {
            Section("Agent needs input") {
                Toggle("Notification", isOn: $needsInputNotification)
                SoundPicker(selection: $needsInputSound)
            }

            Section {
                Toggle("Notification", isOn: $finishedNotification)
                SoundPicker(selection: $finishedSound)
            } header: {
                Text("Agent finished")
            } footer: {
                Text("Agent alerts are only for terminals that are not visible. Notifications for finished commands follow Ghostty's `notify-on-command-finish` settings.")
                    .settingsFooter()
            }
        }
        .formStyle(.grouped)
    }
}

/// The macOS alert sounds, played as they are picked.
private struct SoundPicker: View {
    @Binding var selection: String

    var body: some View {
        Picker("Sound", selection: $selection) {
            Text("None").tag("")
            Divider()
            ForEach(Preferences.sounds, id: \.self) { name in
                Text(name).tag(name)
            }
        }
        .onChange(of: selection) {
            NSSound(named: selection)?.play()
        }
    }
}
