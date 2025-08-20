import SwiftUI
import Carbon

@main
struct WhisperTranscriberApp: App {
    @StateObject private var vm = RecorderViewModel.shared
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var logStore = LogStore.shared

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
            Image(nsImage: tintedImage(named: "icon", color: getForegroundColor(vm: vm)))
        }
        .menuBarExtraStyle(.window)
        .commands {
            appCommands
        }
    }
}

private extension WhisperTranscriberApp {
    @CommandsBuilder
    var appCommands: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Show Logs") {
                LogWindowController.shared.toggle()
            }
            .keyboardShortcut("l", modifiers: [.command, .control])
        }
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
            return .white
        }
    }

    func tintedImage(named name: String, color: Color) -> NSImage {
        let nsColor = NSColor(color)
        guard let image = NSImage(named: name)?.copy() as? NSImage else { return NSImage() }
        image.lockFocus()
        nsColor.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
