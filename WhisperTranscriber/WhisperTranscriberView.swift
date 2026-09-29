import SwiftUI

struct WhisperTranscriberView: View {
    @StateObject private var vm = RecorderViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared

    var showRecords: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            if vm.isPrewarming {
                PrewarmingView(isDownloading: vm.isDownloading, downloadProgress: vm.downloadProgress)
            } else {
                IdleRecordingView(
                    settings: settings,
                    isRecording: vm.isRecording,
                    isTranscribing: vm.isTranscribing,
                    livePreview: vm.livePreview,
                    showRecords: showRecords
                )
            }
        }
        .alert(isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(vm.errorMessage ?? "An unexpected error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct PrewarmingView: View {
    var isDownloading: Bool
    var downloadProgress: Double
    var body: some View {
        VStack {
            if (isDownloading) {
                Text("Parakeet is downloading...")
                Text("This just happens once per install")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                ProgressView(value: downloadProgress, total: 1.0)
                Divider()
                Text("If you want to avoid this, download the non-lite version of WhisperTranscriber")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Text("Parakeet is loading...")
                Text("This takes about a second on the Neural Engine")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                ProgressView()
            }

            Button("Quit WhisperTranscriber", action: { NSApp.terminate(nil) })
                .keyboardShortcut("Q")
        }
        .padding(10)
    }
}

struct LivePreviewView: View {
    var text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(width: 200, height: 64)
        .padding(4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
    }
}

struct IdleRecordingView: View {
    @ObservedObject var settings: SettingsManager
    var isRecording: Bool
    var isTranscribing: Bool
    var livePreview: String
    var showRecords: () -> Void

    private func statusText() -> String {
        if isTranscribing {
            return "🔄 Transcribing…"
        } else if isRecording {
            return "🛑 Recording…"
        } else {
            return "▶️ Idle"
        }
    }

    var body: some View {
        VStack(spacing: 8) {


            Text("Toggle Shortcut:")
                .font(.subheadline)
                .disabled(true)

            HotkeyRecorderView(chord: $settings.hotkey) { newChord in
                let old = settings.hotkey
                settings.hotkey = newChord
                if !HotKeyManager.shared.register(chord: newChord, handler: { Task { @MainActor in RecorderViewModel.shared.toggleRecording() } }) {
                    settings.hotkey = old
                    _ = HotKeyManager.shared.register(chord: old, handler: { Task { @MainActor in RecorderViewModel.shared.toggleRecording() } })
                }
            }
            .frame(width: 80, height: 22)

            Text("Suffix:")
                .font(.subheadline)
                .disabled(true)

            TextField("Enter suffix", text: $settings.suffix)
                .background(Color(NSColor.controlBackgroundColor))
                .multilineTextAlignment(.center)
                .frame(width: 80, height: 22)

            Toggle("Live Transcription", isOn: $settings.liveTranscriptionEnabled)
                .disabled(isRecording)
                .help("Locked in when a recording starts. Off records silently and transcribes once at the end.")

            Toggle("Detect Speakers", isOn: $settings.speakerDetectionEnabled)
                .disabled(isRecording)
                .help("Labels each turn in the final transcript. For conversations, not dictation. Downloads ~130MB the first time.")

            DisclosureGroup("Advanced") {
                VStack(spacing: 4) {
                    Toggle("Fade Volume", isOn: $settings.fadeVolumeEnabled)

                    if settings.fadeVolumeEnabled {
                        Text("Fade Milliseconds:")
                            .font(.subheadline)
                            .disabled(true)

                        TextField("Fade Milliseconds", value: $settings.fadeMilliseconds, formatter: NumberFormatter())
                            .background(Color(NSColor.controlBackgroundColor))
                            .multilineTextAlignment(.center)
                            .frame(width: 80, height: 22)
                    }

                    Toggle("Clean Up Text", isOn: $settings.cleanupEnabled)

                    if settings.cleanupEnabled {
                        Toggle("Also Remove \"um\"", isOn: $settings.removeUm)
                    }
                }
            }

            if !livePreview.isEmpty {
                LivePreviewView(text: livePreview)
            }

            Text(statusText())
                .disabled(true)

            Divider()

            Button("Records") {
                showRecords()
            }

            Button("Quit WhisperTranscriber", action: { NSApp.terminate(nil) })
                .keyboardShortcut("Q")
        }
        .padding(10)
        .fixedSize()
    }
}


struct WhisperTranscriberView_Previews: PreviewProvider {
    static var previews: some View {

        Group {
            PrewarmingView(isDownloading: true, downloadProgress: 0)
                .previewDisplayName("Downloading")
                .fixedSize()

            PrewarmingView(isDownloading: false, downloadProgress: 0)
                .previewDisplayName("Prewarming")
                .fixedSize()

            IdleRecordingView(
                settings: SettingsManager.shared,
                isRecording: false,
                isTranscribing: false,
                livePreview: "",
                showRecords: {}
            )
            .previewDisplayName("Idle/Recording")
            .fixedSize()

            IdleRecordingView(
                settings: SettingsManager.shared,
                isRecording: true,
                isTranscribing: false,
                livePreview: "This is what a live transcript looks like as it streams in.",
                showRecords: {}
            )
            .previewDisplayName("Live Preview")
            .fixedSize()
        }
    }
}
