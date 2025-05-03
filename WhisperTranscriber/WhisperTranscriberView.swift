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
                PrewarmingView()
            } else {
                IdleRecordingView(
                    hotkey: $hotkey,
                    suffix: $suffix,
                    registerShortcut: registerShortcut,
                    isRecording: vm.isRecording
                )
            }
        }
    }
}
struct PrewarmingView: View {
    var body: some View {
        VStack {
            Text("WhisperKit is loading...")
            ProgressView()
        }
        .padding(10)
    }
}

struct IdleRecordingView: View {
    @Binding var hotkey: String
    @Binding var suffix: String
    var registerShortcut: (String) -> Bool
    var isRecording: Bool

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
            
            Text(isRecording ? "🛑 Recording…" : "▶️ Idle")
                .disabled(true)
            
            Divider()
            
            Button("Quit WhisperTranscriber", action: { NSApp.terminate(nil) })
                .keyboardShortcut("Q")
        }
    }
}


struct WhisperTranscriberView_Previews: PreviewProvider {
    static var previews: some View {
        
        Group {
            PrewarmingView()
                .previewDisplayName("Prewarming")
                .fixedSize()
            
            IdleRecordingView(
                hotkey: .constant("⌥⌘S"),
                suffix: .constant(""),
                registerShortcut: { _ in true },
                isRecording: false
            )
            .previewDisplayName("Idle/Recording")
            .fixedSize()
        }
    }
}


