import Foundation
import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.whispertranscriber"

    static let app = Logger(subsystem: subsystem, category: "Application")
    static let whisper = Logger(subsystem: subsystem, category: "WhisperKit")
    static let crash = Logger(subsystem: subsystem, category: "CrashHandler")
}
