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
            Image(systemName: "mic.fill")
              .symbolRenderingMode(.palette)
              .foregroundStyle(
                foregroundColor(),
                .primary // keep secondary layer default
              )
          }
        .menuBarExtraStyle(.window)
    }

    private func foregroundColor() -> Color {
        switch true {
        case vm.isTranscribing:
            return .blue // whisper is running
        case vm.isPrewarming:
            return .red // pre-warming in progress
        case vm.isRecording:
            return .orange // actively recording
        default:
            return .white // idle
        }
    }
    @discardableResult
    private func registerShortcut(_ chord: String) -> Bool {
        // 1) figure out modifiers
        let modMap: [(String, UInt32)] = [
            ("⌥", UInt32(optionKey)),
            ("⌃", UInt32(controlKey)),
            ("⇧", UInt32(shiftKey)),
            ("⌘", UInt32(cmdKey))
        ]
        let modifiers = modMap.reduce(0) { acc, pair in
            chord.contains(pair.0) ? acc | pair.1 : acc
        }

        // 2) pick the *last* letter or digit in the string
        guard let lastChar = chord.last(where: { $0.isLetter || $0.isNumber }),
              let vk       = virtualKeyCode(for: lastChar)
        else {
            print("❌ couldn’t parse hotkey:", chord)
            return false
        }

        // 3) unregister old, register new
        HotKeyManager.unregisterAll()
        HotKeyManager.register(
            keyCode: vk,
            modifiers: modifiers,
            id: vk
        ) {
            RecorderViewModel.shared.toggleRecording()
        }

        print("✅ Registered", chord,
              "→ keyCode:", vk, "mods:", modifiers)
        return true
    }

    private func virtualKeyCode(for char: Character) -> UInt32? {
        let keyMap: [Character: UInt32] = [
            "A": UInt32(kVK_ANSI_A), "B": UInt32(kVK_ANSI_B), "C": UInt32(kVK_ANSI_C),
            "D": UInt32(kVK_ANSI_D), "E": UInt32(kVK_ANSI_E), "F": UInt32(kVK_ANSI_F),
            "G": UInt32(kVK_ANSI_G), "H": UInt32(kVK_ANSI_H), "I": UInt32(kVK_ANSI_I),
            "J": UInt32(kVK_ANSI_J), "K": UInt32(kVK_ANSI_K), "L": UInt32(kVK_ANSI_L),
            "M": UInt32(kVK_ANSI_M), "N": UInt32(kVK_ANSI_N), "O": UInt32(kVK_ANSI_O),
            "P": UInt32(kVK_ANSI_P), "Q": UInt32(kVK_ANSI_Q), "R": UInt32(kVK_ANSI_R),
            "S": UInt32(kVK_ANSI_S), "T": UInt32(kVK_ANSI_T), "U": UInt32(kVK_ANSI_U),
            "V": UInt32(kVK_ANSI_V), "W": UInt32(kVK_ANSI_W), "X": UInt32(kVK_ANSI_X),
            "Y": UInt32(kVK_ANSI_Y), "Z": UInt32(kVK_ANSI_Z), "0": UInt32(kVK_ANSI_0),
            "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2), "3": UInt32(kVK_ANSI_3),
            "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5), "6": UInt32(kVK_ANSI_6),
            "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8), "9": UInt32(kVK_ANSI_9)
        ]
        return keyMap[char.uppercased().first ?? Character("")]
    }

}

