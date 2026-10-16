import SwiftUI
import Carbon
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    // Hold a strong reference to the activity token to keep the app alive
    var lifetimeActivity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create a focused activity to stop the OS from killing the app as "NonInteractive"
        self.lifetimeActivity = ProcessInfo.processInfo.beginActivity(
             options: [.userInitiated, .suddenTerminationDisabled, .automaticTerminationDisabled],
             reason: "App operates as an agent and must remain active"
        )
        
        // Explicitly disable automatic termination
        // This reinforces the ProcessInfo assertion against CacheDelete/RunningBoard
        ProcessInfo.processInfo.disableAutomaticTermination("Agent must remain active")
        
        Log.setupFileLogging()
        CrashHandler.shared.setup()
        
        HotKeyManager.shared.register(chord: SettingsManager.shared.hotkey) {
             Task { @MainActor in
                 RecorderViewModel.shared.toggleRecording()
             }
        }
    }
}

@main
struct WhisperTranscriberApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var vm = RecorderViewModel.shared
    @StateObject private var settings = SettingsManager.shared

    var body: some Scene {
        MenuBarExtra {
            WhisperTranscriberView()
        } label: {
            Image(nsImage: tintedImage(named: "icon", color: getForegroundColor(vm: vm)))
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(after: .appInfo) {
                ShowRecordsCommand()
            }
        }

        Window("Records", id: RecordsView.windowID) {
            RecordsView()
        }
        .defaultSize(width: 480, height: 560)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView(settings: settings)
        }
    }
}

private struct ShowRecordsCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Records") {
            openWindow(id: RecordsView.windowID)
            NSApp.activate()
        }
        .keyboardShortcut("r", modifiers: [.command, .control])
    }
}

private extension WhisperTranscriberApp {
    func getForegroundColor(vm: RecorderViewModel) -> Color {
        switch vm.activity {
        case .downloading:
            return .purple
        case .preparing:
            return .red
        case .transcribing:
            return .blue
        case .recordingLive:
            return .darkOrange
        case .recording:
            return .orange
        case .idle:
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