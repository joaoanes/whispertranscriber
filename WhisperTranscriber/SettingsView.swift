import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("Recording") {
                LabeledContent("Toggle shortcut") {
                    HotkeyRecorderView(chord: $settings.hotkey, onChordCaptured: rebind)
                        .frame(width: 100, height: 22)
                }
                TextField("Transcript suffix", text: $settings.suffix, prompt: Text("None"))
            }

            Section("Volume") {
                Toggle("Fade volume while recording", isOn: $settings.fadeVolumeEnabled)
                LabeledContent("Fade duration") {
                    Stepper(
                        "\(settings.fadeMilliseconds) ms",
                        value: $settings.fadeMilliseconds,
                        in: 0...5000,
                        step: 100
                    )
                }
                .disabled(!settings.fadeVolumeEnabled)
            }

            Section("Text") {
                Toggle("Clean up text", isOn: $settings.cleanupEnabled)
                Toggle("Also remove \"um\"", isOn: $settings.removeUm)
                    .disabled(!settings.cleanupEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func rebind(to chord: String) {
        let previous = settings.hotkey
        settings.hotkey = chord
        guard !HotKeyManager.shared.register(chord: chord, handler: toggleRecording) else { return }
        settings.hotkey = previous
        _ = HotKeyManager.shared.register(chord: previous, handler: toggleRecording)
    }

    private func toggleRecording() {
        Task { @MainActor in RecorderViewModel.shared.toggleRecording() }
    }
}

#Preview {
    SettingsView(settings: .shared)
}
