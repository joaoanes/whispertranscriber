import SwiftUI
import Carbon

@main
struct WhisperTranscriberApp: App {
    @StateObject private var vm = RecorderViewModel.shared
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var logStore = LogStore.shared

    init() {
        // By accessing LogStore.shared here, we ensure its init() runs
        // before anything else in this init() method.
        let _ = LogStore.shared
        HotKeyManager.shared.register(chord: settings.hotkey) {
            Task { @MainActor in
                RecorderViewModel.shared.toggleRecording()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Text(statusText(vm: vm))
                .disabled(true)
            Text("Shortcut: \(settings.hotkey)")
                .disabled(true)
            Divider()
            Button("Settings...") {
                SettingsWindowController.shared.showWindow()
            }
            Divider()
            Button("Show Records") {
                RecordsWindowController.shared.showWindow()
            }
            Button("Show Logs") {
                LogWindowController.shared.toggle()
            }
            Divider()
            Button("About WhisperTranscriber") {
                AboutWindowController.shared.showWindow()
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
        } label: {
            Image(nsImage: tintedImage(named: "icon", color: getForegroundColor(vm: vm)))
        }
        .menuBarExtraStyle(.menu)
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
    func statusText(vm: RecorderViewModel) -> String {
        if vm.isDownloading {
            return "Downloading model..."
        }
        if vm.isPrewarming {
            return "Loading model..."
        }
        if vm.isTranscribing {
            return "🔄 Transcribing..."
        }
        if vm.isRecording {
            return "🛑 Recording..."
        }
        return "▶️ Idle"
    }

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
