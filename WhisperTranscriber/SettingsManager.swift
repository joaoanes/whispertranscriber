import Foundation
import SwiftUI

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @AppStorage("toggleHotkey") var hotkey: String = "⌥⌘S"
    @AppStorage("transcriptionSuffix") var suffix: String = ""

    private init() {
        // We can add any initialization logic here if needed in the future.
    }
}
