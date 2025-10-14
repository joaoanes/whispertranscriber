import Foundation
import Combine

@MainActor
class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published var logMessages: [String] = []

    private var pipe = Pipe()
    private var originalStdout: Int32
    private var originalStderr: Int32
    private var logFileHandle: FileHandle?
    private var cancellable: AnyCancellable?

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

            self.logFileHandle?.write(data)

            // Write the data back to the original stdout
            var dataCopy = data
            dataCopy.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                if let baseAddress = ptr.baseAddress {
                    write(self.originalStdout, baseAddress, data.count)
                }
            }

            if let string = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.logMessages.append(string)
                    if self.logMessages.count > 300 {
                        self.logMessages.removeFirst(self.logMessages.count - 300)
                    }
                }
            }
        }
    }

    deinit {
        logFileHandle?.closeFile()
        // Restore original stdout and stderr
        dup2(originalStdout, STDOUT_FILENO)
        dup2(originalStderr, STDERR_FILENO)
        close(originalStdout)
        close(originalStderr)
    }
}
