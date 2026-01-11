import Foundation
import AppKit

private func globalSignalHandler(_ signal: Int32) {
    CrashHandler.shared.handleSignal(signal)
}

private func globalUncaughtExceptionHandler(_ exception: NSException) {
    CrashHandler.shared.handleException(exception)
}

class CrashHandler {
    static let shared = CrashHandler()

    private init() {}

    func setup() {
        NSSetUncaughtExceptionHandler(globalUncaughtExceptionHandler)

        signal(SIGABRT, globalSignalHandler)
        signal(SIGSEGV, globalSignalHandler)
        signal(SIGBUS, globalSignalHandler)
        signal(SIGTRAP, globalSignalHandler)
        signal(SIGILL, globalSignalHandler)
    }

    func handleException(_ exception: NSException) {
        let message = "Uncaught Exception: \(exception.name.rawValue)\nReason: \(exception.reason ?? "Unknown")\n\nStack Trace:\n\(exception.callStackSymbols.joined(separator: "\n"))"
        Log.general.fault("Uncaught Exception: \(exception.name.rawValue))\nReason: \(exception.reason ?? "Unknown"))\nStack Trace:\n\(exception.callStackSymbols.joined(separator: "\n")))")
        presentCrashWindow(message: message)
    }

    func handleSignal(_ signalVal: Int32) {
        var signalName = "Unknown Signal (\(signalVal))"
        switch signalVal {
        case SIGABRT: signalName = "SIGABRT (Abort)"
        case SIGSEGV: signalName = "SIGSEGV (Segmentation Fault)"
        case SIGBUS:  signalName = "SIGBUS (Bus Error)"
        case SIGTRAP: signalName = "SIGTRAP (Trace/BPT trap)"
        case SIGILL:  signalName = "SIGILL (Illegal Instruction)"
        default: break
        }

        let message = "Application Crashed\nSignal: \(signalName)\n\nStack Trace:\n\(Thread.callStackSymbols.joined(separator: "\n"))"
        Log.general.fault("Application Crashed\nSignal: \(signalName))\nStack Trace:\n\(Thread.callStackSymbols.joined(separator: "\n")))")
        
        presentCrashWindow(message: message)
    }

    private func presentCrashWindow(message: String) {
        // 1. Save crash log to disk
        let logPath = saveCrashLog(message)

        let finalMessage = """
        The application encountered a critical error and needs to close.

        A crash report has been saved to:
        \(logPath ?? "Unknown location")

        Error Details:
        \(message)
        """

        // 2. Show Alert
        // We try to run this on the main thread.
        let runAlert = {
            let alert = NSAlert()
            alert.messageText = "Whisper Transcriber Crashed"
            alert.informativeText = finalMessage
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")

            // This blocks until the user clicks the button
            alert.runModal()

            // We don't exit(1) anymore because we want the system to generate a crash report (.ips)
            // if we are in a signal handler or uncaught exception.
            // Returning will let the app continue to its demise.
        }

        if Thread.isMainThread {
            runAlert()
        } else {
            DispatchQueue.main.sync {
                runAlert()
            }
        }

        // Fallback: if we are here, exit anyway
        exit(1)
    }

    private func saveCrashLog(_ message: String) -> String? {
        let fileManager = FileManager.default
        // Use getpwuid to get the real home directory, bypassing sandbox container
        guard let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir else { return nil }
        let homeDir = String(cString: home)
        let crashDir = URL(fileURLWithPath: homeDir)
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("WhisperTranscriber")

        do {
            if !FileManager.default.fileExists(atPath: crashDir.path) {
                try FileManager.default.createDirectory(at: crashDir, withIntermediateDirectories: true, attributes: nil)
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let filename = "Crash_\(dateFormatter.string(from: Date())).txt"
            let fileURL = crashDir.appendingPathComponent(filename)

            try message.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL.path
        } catch {
            Log.general.error("Failed to save crash log: \(error.localizedDescription))")
            return nil
        }
    }
}
