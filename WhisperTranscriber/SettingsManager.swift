import Foundation
import SwiftUI

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @AppStorage("toggleHotkey") var hotkey: String = "⌥⌘S"
    @AppStorage("transcriptionSuffix") var suffix: String = ""
    @AppStorage("fadeVolumeEnabled") var fadeVolumeEnabled: Bool = true
    @AppStorage("fadeMilliseconds") var fadeMilliseconds: Int = 500
    @AppStorage("liveTranscriptionEnabled") var liveTranscriptionEnabled: Bool = true
    @AppStorage("cleanupEnabled") var cleanupEnabled: Bool = true
    @AppStorage("removeUm") var removeUm: Bool = false
    @AppStorage("speakerDetectionEnabled") var speakerDetectionEnabled: Bool = false

    var cleanupOptions: TextCleanupOptions {
        guard cleanupEnabled else { return .disabled }
        return TextCleanupOptions(enabled: true, removeUm: removeUm)
    }

    private init() {
    }
}
