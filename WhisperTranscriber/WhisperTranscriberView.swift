import SwiftUI

struct WhisperTranscriberView: View {
    @StateObject private var vm = RecorderViewModel.shared
    @AppStorage("toggleHotkey") private var hotkey = "⌥⌘S"
    @AppStorage("transcriptionSuffix") private var suffix = ""
    
    var registerShortcut: (String) -> Bool
    
    var body: some View {
        ZStack {
            Color.clear // full-size hit area
                .contentShape(Rectangle())
                .onTapGesture {
                    // deselect our capture view if it’s focused
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            if vm.isPrewarming {
                PrewarmingView(isDownloading: vm.isDownloading, downloadProgress: vm.downloadProgress)
            } else {
                IdleRecordingView(
                    hotkey: $hotkey,
                    suffix: $suffix,
                    registerShortcut: registerShortcut,
                    isRecording: vm.isRecording,
                    isTranscribing:
                        vm.isTranscribing
                )
            }
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
    @Binding var hotkey: String
    @Binding var suffix: String
    var registerShortcut: (String) -> Bool
    var isRecording: Bool
    var isTranscribing: Bool

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
            
            HotkeyRecorderView(chord: $hotkey) { newChord in
                let old = hotkey
                hotkey = newChord
                if !registerShortcut(newChord) {
                    hotkey = old
                    _ = registerShortcut(old)
                }
            }
            .frame(width: 80, height: 22)
            
            Text("Suffix:")
                .font(.subheadline)
                .disabled(true)
            
            TextField("Enter suffix", text: $suffix)
                .background(Color(NSColor.controlBackgroundColor))
                .multilineTextAlignment(.center)
                .frame(width: 80, height: 22)
            
            Text(statusText())
                .disabled(true)
            
            Divider()
            
            Button("Quit WhisperTranscriber", action: { NSApp.terminate(nil) })
                .keyboardShortcut("Q")
        }.padding(10)
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
                hotkey: .constant("⌥⌘S"),
                suffix: .constant(""),
                registerShortcut: { _ in true },
                isRecording: false,
                isTranscribing: false
            )
            .previewDisplayName("Idle/Recording")
            .fixedSize()
        }
    }
}


