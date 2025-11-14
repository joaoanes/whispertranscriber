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
                Text("WhisperKit is downloading...")
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
                Text("WhisperKit is loading...")
                Text("This can take up to one minute on the first open")
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

struct IdleRecordingView: View {
    @ObservedObject var settings: SettingsManager
    @StateObject private var vm = RecorderViewModel.shared
    var isRecording: Bool
    var isTranscribing: Bool
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

                    Text("Model:")
                        .font(.subheadline)
                        .disabled(true)

                    Picker("Model", selection: $settings.selectedModel) {
                        ForEach(AvailableModels.modelNames, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: settings.selectedModel) {
                        Task {
                            await vm.reinitWhisperKit()
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)

                    Toggle("Log to file", isOn: $settings.logToFile)

                    if settings.logToFile {
                        if let logFileURL = LogStore.shared.logFileURL {
                            Button(action: {
                                NSWorkspace.shared.open(logFileURL)
                            }) {
                                Text(logFileURL.path)
                                    .truncationMode(.middle)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
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
                showRecords: {}
            )
            .previewDisplayName("Idle/Recording")
            .fixedSize()
        }
    }
}