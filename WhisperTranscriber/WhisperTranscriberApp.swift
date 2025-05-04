import SwiftUI
import Carbon

@main
struct WhisperTranscriberApp: App {
    @StateObject private var vm = RecorderViewModel.shared
    @AppStorage("toggleHotkey") private var hotkey = "⌥⌘S"
    @AppStorage("transcriptionSuffix") private var suffix = ""

    init() {
        registerShortcut(hotkey)
    }

    var body: some Scene {
        MenuBarExtra {
            WhisperTranscriberView(registerShortcut: registerShortcut)
        } label: {
            Image(nsImage: tintedImage(named: "icon", color: getForegroundColor(vm: vm)))
          }
        .menuBarExtraStyle(.window)
    }
}

