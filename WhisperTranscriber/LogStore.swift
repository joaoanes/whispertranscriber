import Foundation
import Combine

struct LogMessage: Identifiable, Hashable {
    let id: Int // Use incrementing counter instead of UUID for stable identity
    let message: String
}

@MainActor
class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published var logMessages: [LogMessage] = []

    private var pipe = Pipe()
    private var originalStdout: Int32
    private var originalStderr: Int32
    private var logFileHandle: FileHandle?
    private var cancellable: AnyCancellable?
    private var logBuffer: String = ""
    private var updateTimer: Timer?
    private var messageIdCounter: Int = 0 // Counter for stable IDs

    public var logFileURL: URL? {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDirectory = applicationSupport.appendingPathComponent("WhisperTranscriber")
        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        return appDirectory.appendingPathComponent("WhisperTranscriber.log")
    }

    private init() {
        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)

        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)

        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        cancellable = SettingsManager.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let logToFile = SettingsManager.shared.logToFile
                if logToFile {
                    if self.logFileHandle == nil {
                        if let logFileURL = self.logFileURL {
                            do {
                                if !FileManager.default.fileExists(atPath: logFileURL.path) {
                                    FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
                                }
                                self.logFileHandle = try FileHandle(forWritingTo: logFileURL)
                                self.logFileHandle?.seekToEndOfFile()
                            } catch {
                                print("Error opening log file: \(error)")
                            }
                        }
                    }
                } else {
                    self.logFileHandle?.closeFile()
                    self.logFileHandle = nil
                }
            }
        }

        if SettingsManager.shared.logToFile {
            if let logFileURL = self.logFileURL {
                do {
                    if !FileManager.default.fileExists(atPath: logFileURL.path) {
                        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
                    }
                    self.logFileHandle = try FileHandle(forWritingTo: logFileURL)
                    self.logFileHandle?.seekToEndOfFile()
                } catch {
                    print("Error opening log file: \(error)")
                }
            }
        }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let self = self else { return }
            let data = fileHandle.availableData

            Task { @MainActor in
                self.logFileHandle?.write(data)
                var dataCopy = data
                dataCopy.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                    if let baseAddress = ptr.baseAddress {
                        write(self.originalStdout, baseAddress, data.count)
                    }
                }
                if let string = String(data: data, encoding: .utf8) {
                    // Filter out OSLog binary data - only keep lines that look like actual log messages
                    let lines = string.components(separatedBy: .newlines)
                    for line in lines {
                        // Skip OSLog binary format lines (they start with "OSLOG-" or contain mostly control chars)
                        if line.hasPrefix("OSLOG-") || line.isEmpty {
                            continue
                        }
                        // Only append lines that have mostly printable characters
                        let printableCount = line.filter { $0.isASCII && !$0.isWhitespace && !$0.isNewline }.count
                        if printableCount > 5 { // Arbitrary threshold for "real" log lines
                            self.logBuffer.append(line + "\n")
                        }
                    }
                }
            }
        }

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flushLogBuffer()
            }
        }
        updateTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func flushLogBuffer() {
        guard !logBuffer.isEmpty else { return }

        var newEntries: [LogMessage] = []

        logBuffer.enumerateLines { line, _ in
            if !line.isEmpty {
                self.messageIdCounter += 1
                newEntries.append(LogMessage(id: self.messageIdCounter, message: line))
            }
        }

        logBuffer = ""

        // Batch updates to reduce UI thrashing
        if newEntries.isEmpty { return }

        // Atomic update: create new array with existing + new entries, then trim
        // This triggers only ONE SwiftUI update instead of two
        var updatedMessages = logMessages + newEntries
        if updatedMessages.count > 100 {
            updatedMessages = Array(updatedMessages.suffix(100))
        }
        logMessages = updatedMessages
    }

    public func appendToLogBuffer(_ message: String) {
        logBuffer.append(message)
    }

    deinit {
        updateTimer?.invalidate()
        logFileHandle?.closeFile()
        // Restore original stdout and stderr
        dup2(originalStdout, STDOUT_FILENO)
        dup2(originalStderr, STDERR_FILENO)
        close(originalStdout)
        close(originalStderr)
    }
}
