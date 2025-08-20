import Foundation
import Combine

class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published var logMessages: [String] = []

    private var pipe = Pipe()
    private var originalStdout: Int32
    private var originalStderr: Int32

    private init() {
        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)

        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)

        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let self = self else { return }
            let data = fileHandle.availableData

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
                }
            }
        }
    }

    deinit {
        // Restore original stdout and stderr
        dup2(originalStdout, STDOUT_FILENO)
        dup2(originalStderr, STDERR_FILENO)
        close(originalStdout)
        close(originalStderr)
    }
}
