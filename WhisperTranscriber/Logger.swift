import os
import Foundation

/// Centralized logging that writes to both OSLog and a file in ~/Library/Logs
struct Log {
    static let subsystem = "com.joaoanes.WhisperTranscriber"
    
    // OSLog instances
    private static let osGeneral = Logger(subsystem: subsystem, category: "general")
    private static let osWhisperKit = Logger(subsystem: subsystem, category: "whisperkit")
    private static let osRecording = Logger(subsystem: subsystem, category: "recording")
    private static let osHotkey = Logger(subsystem: subsystem, category: "hotkey")
    
    // Dual-output loggers
    static let general = DualLogger(osLogger: osGeneral, category: "general")
    static let whisperKit = DualLogger(osLogger: osWhisperKit, category: "whisperkit")
    static let recording = DualLogger(osLogger: osRecording, category: "recording")
    static let hotkey = DualLogger(osLogger: osHotkey, category: "hotkey")
    
    // File handle for log file
    private static var fileHandle: FileHandle?
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df
    }()
    
    static func setupFileLogging() {
        guard let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir else { return }
        let homeDir = String(cString: home)
        let logDir = URL(fileURLWithPath: homeDir)
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("WhisperTranscriber")
        
        do {
            try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
            let logFile = logDir.appendingPathComponent("app.log")
            
            if !FileManager.default.fileExists(atPath: logFile.path) {
                FileManager.default.createFile(atPath: logFile.path, contents: nil, attributes: nil)
            }
            
            fileHandle = try FileHandle(forWritingTo: logFile)
            fileHandle?.seekToEndOfFile()
            writeToFile("--- App Started ---")
        } catch {
            osGeneral.error("Failed to setup file logging: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    static func writeToFile(_ message: String, category: String = "general", level: String = "INFO") {
        guard let handle = fileHandle else { return }
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] [\(category)] \(message)\n"
        if let data = line.data(using: .utf8) {
            handle.write(data)
        }
    }
}

/// A logger that writes to both OSLog and a file
struct DualLogger {
    let osLogger: Logger
    let category: String
    
    func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .public)")
        Log.writeToFile(message, category: category, level: "DEBUG")
    }
    
    func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        Log.writeToFile(message, category: category, level: "INFO")
    }
    
    func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        Log.writeToFile(message, category: category, level: "ERROR")
    }
    
    func fault(_ message: String) {
        osLogger.fault("\(message, privacy: .public)")
        Log.writeToFile(message, category: category, level: "FAULT")
    }
}
