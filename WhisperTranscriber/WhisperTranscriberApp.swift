import SwiftUI
import Carbon

@main
struct WhisperTranscriberApp: App {
    @StateObject private var vm = RecorderViewModel.shared
    @AppStorage("toggleHotkey") private var hotkey = "⌥⌘S"

    init() {
        registerShortcut(hotkey)
    }

    var body: some Scene {
        MenuBarExtra {
            // Wrap the whole menu in a ZStack so we can catch any click-away
            ZStack {
                Color.clear // full-size hit area
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // deselect our capture view if it’s focused
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    }

                VStack(spacing: 8) {
                    Text("Toggle Shortcut:")
                        .font(.subheadline)
                        .disabled(true)

                    HotkeyRecorderView(chord: $hotkey) { newChord in
                        // attempt to parse & register; revert on failure
                        let old = hotkey
                        hotkey = newChord
                        if registerShortcut(newChord) == false {
                            hotkey = old
                            registerShortcut(old)
                        }
                    }
                    .frame(width: 80, height: 22)

                    Divider()

                    Text(vm.isRecording ? "🛑 Recording…" : "▶️ Idle")
                        .disabled(true)

                    Divider()

                    Button("Quit WhisperTranscriber", action: { NSApp.terminate(nil) })
                        .keyboardShortcut("Q")
                }
                .padding(12)
            }
        } label: {
            Image(systemName: "mic.fill")
              .symbolRenderingMode(.palette)
              .foregroundStyle(
                vm.isTranscribing
                  ? .blue        // whisper is running
                  : vm.isRecording
                    ? .orange    // actively recording
                    : .white,    // idle
                .primary        // keep secondary layer default
              )
          }
        .menuBarExtraStyle(.window)
    }

    /// Parses and registers. Returns `true` on success; `false` on failure.
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
        switch char.uppercased() {
        case "A": return UInt32(kVK_ANSI_A)
        case "B": return UInt32(kVK_ANSI_B)
        case "C": return UInt32(kVK_ANSI_C)
        case "D": return UInt32(kVK_ANSI_D)
        case "E": return UInt32(kVK_ANSI_E)
        case "F": return UInt32(kVK_ANSI_F)
        case "G": return UInt32(kVK_ANSI_G)
        case "H": return UInt32(kVK_ANSI_H)
        case "I": return UInt32(kVK_ANSI_I)
        case "J": return UInt32(kVK_ANSI_J)
        case "K": return UInt32(kVK_ANSI_K)
        case "L": return UInt32(kVK_ANSI_L)
        case "M": return UInt32(kVK_ANSI_M)
        case "N": return UInt32(kVK_ANSI_N)
        case "O": return UInt32(kVK_ANSI_O)
        case "P": return UInt32(kVK_ANSI_P)
        case "Q": return UInt32(kVK_ANSI_Q)
        case "R": return UInt32(kVK_ANSI_R)
        case "S": return UInt32(kVK_ANSI_S)
        case "T": return UInt32(kVK_ANSI_T)
        case "U": return UInt32(kVK_ANSI_U)
        case "V": return UInt32(kVK_ANSI_V)
        case "W": return UInt32(kVK_ANSI_W)
        case "X": return UInt32(kVK_ANSI_X)
        case "Y": return UInt32(kVK_ANSI_Y)
        case "Z": return UInt32(kVK_ANSI_Z)
        case "0": return UInt32(kVK_ANSI_0)
        case "1": return UInt32(kVK_ANSI_1)
        case "2": return UInt32(kVK_ANSI_2)
        case "3": return UInt32(kVK_ANSI_3)
        case "4": return UInt32(kVK_ANSI_4)
        case "5": return UInt32(kVK_ANSI_5)
        case "6": return UInt32(kVK_ANSI_6)
        case "7": return UInt32(kVK_ANSI_7)
        case "8": return UInt32(kVK_ANSI_8)
        case "9": return UInt32(kVK_ANSI_9)
        default:  return nil
        }
    }

}
