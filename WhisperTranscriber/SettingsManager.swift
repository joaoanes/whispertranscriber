import Foundation
import SwiftUI

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @AppStorage("toggleHotkey") var hotkey: String = "⌥⌘S"
    @AppStorage("transcriptionSuffix") var suffix: String = ""
    @AppStorage("selectedModel") var selectedModel: String = "openai_whisper-large-v3-v20240930"
    @AppStorage("fadeMilliseconds") var fadeMilliseconds: Int = 500
    @AppStorage("logToFile") var logToFile: Bool = false

    private init() {
        // We can add any initialization logic here if needed in the future.
    }
}
