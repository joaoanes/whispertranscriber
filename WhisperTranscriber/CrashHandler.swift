import Foundation
import AppKit
import OSLog

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
        let message = """
        Uncaught Exception: \(exception.name.rawValue)
        Reason: \(exception.reason ?? "Unknown")

        Stack Trace:
        \(exception.callStackSymbols.joined(separator: "\n"))
        """

        Logger.crash.fault("\(message, privacy: .public)")
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

        let message = """
        Application Crashed
        Signal: \(signalName)

        Stack Trace:
        \(Thread.callStackSymbols.joined(separator: "\n"))
        """

        Logger.crash.fault("\(message, privacy: .public)")
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

            // Force exit after user dismisses
            exit(1)
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
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let crashDir = applicationSupport
            .appendingPathComponent("WhisperTranscriber")
            .appendingPathComponent("CrashLogs")

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
            print("Failed to save crash log: \(error)")
            return nil
        }
    }
}
