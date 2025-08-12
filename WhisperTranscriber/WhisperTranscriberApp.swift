import SwiftUI
import Carbon

@main
struct WhisperTranscriberApp: App {
    @StateObject private var vm = RecorderViewModel.shared
    @StateObject private var settings = SettingsManager.shared

    init() {
        HotKeyManager.shared.register(chord: settings.hotkey) {
            Task { @MainActor in
                RecorderViewModel.shared.toggleRecording()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            WhisperTranscriberView()
        } label: {
            Label("WhisperTranscriber", systemImage: "mic.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(getForegroundColor(vm: vm))
        }
        .menuBarExtraStyle(.window)
    }
}

private extension WhisperTranscriberApp {
    func getForegroundColor(vm: RecorderViewModel) -> Color {
        switch true {
        case vm.isDownloading:
            return .purple
        case vm.isTranscribing:
            return .blue // whisper is running
        case vm.isPrewarming:
            return .red // pre-warming in progress
        case vm.isRecording:
            return .orange // actively recording
        default:
            return .primary // idle
        }
    }
}
