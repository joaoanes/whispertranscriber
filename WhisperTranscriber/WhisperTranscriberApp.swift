import SwiftUI
import Carbon
import WhisperKit

@main
struct WhisperTranscriberApp: App {
    @StateObject private var vm = RecorderViewModel.shared
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var logStore = LogStore.shared

    @State private var logWindowController: LogWindowController?
    @State private var recordsWindowController: RecordsWindowController?

    init() {
        CrashHandler.shared.setup()
        let _ = LogStore.shared
        HotKeyManager.shared.register(chord: settings.hotkey) {
            Task { @MainActor in
                RecorderViewModel.shared.toggleRecording()
            }
        }

        Logging.shared.logLevel = .debug
        Logging.shared.loggingCallback = { message in
            print("[WhisperKit]: \(message)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            WhisperTranscriberView(showRecords: showRecords)
        } label: {
            Image(nsImage: tintedImage(named: "icon", color: getForegroundColor(vm: vm)))
        }
        .menuBarExtraStyle(.window)
        .commands {
            appCommands
        }
    }

    private func showLogs() {
        if logWindowController == nil {
            let controller = LogWindowController()
            controller.onWindowClose = { [self] in
                self.logWindowController = nil
            }
            self.logWindowController = controller
        }
        logWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showRecords() {
        if recordsWindowController == nil {
            let controller = RecordsWindowController()
            controller.onWindowClose = { [self] in
                self.recordsWindowController = nil
            }
            self.recordsWindowController = controller
        }
        recordsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private extension WhisperTranscriberApp {
    @CommandsBuilder
    var appCommands: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Show Logs") {
                showLogs()
            }
            .keyboardShortcut("l", modifiers: [.command, .control])

            Button("Show Records") {
                showRecords()
            }
            .keyboardShortcut("r", modifiers: [.command, .control])

            #if DEBUG
            Divider()
            Button("Simulate Crash") {
                fatalError("Simulated Crash triggered by user")
            }
            .keyboardShortcut("k", modifiers: [.command, .option, .shift])
            #endif
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