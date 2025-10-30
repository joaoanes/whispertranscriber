import XCTest
@testable import WhisperTranscriber

class LogStoreTests: XCTestCase {

    @MainActor
    func testLogStoreBatchingAndLimiting() throws {
        // Given
        let logStore = LogStore.shared
        logStore.logMessages = [] // Clear previous test runs

        // When
        // Simulate receiving 301 individual log lines in a single batch
        for i in 1...301 {
            logStore.appendToLogBuffer("Message \(i)\n")
        }

        // Manually trigger the flush
        logStore.flushLogBuffer()

        // Then
        XCTAssertEqual(logStore.logMessages.count, 300, "After one flush, the messages should be trimmed to 300.")
        XCTAssertEqual(logStore.logMessages.first?.message, "Message 2", "The first message should be Message 2 after trimming.")

        // When
        // Simulate receiving 50 more lines, which should trigger the limit
        for i in 302...351 {
            logStore.appendToLogBuffer("Message \(i)\n")
        }

        logStore.flushLogBuffer()

        // Then
        XCTAssertEqual(logStore.logMessages.count, 300, "Log messages should be limited to 300.")
        XCTAssertEqual(logStore.logMessages.first?.message, "Message 52", "The first message should be Message 52 after trimming.")
        XCTAssertEqual(logStore.logMessages.last?.message, "Message 351", "The last message should be the last one added.")
    }
}
