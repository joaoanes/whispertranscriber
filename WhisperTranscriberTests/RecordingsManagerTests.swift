import XCTest
@testable import WhisperTranscriber

@MainActor
final class RecordingsManagerTests: XCTestCase {

    var recordingsManager: RecordingsManager!
    var testCacheDirectory: URL!
    var fileManager: FileManager!

    override func setUp() async throws {
        try await super.setUp()
        recordingsManager = RecordingsManager.shared
        fileManager = FileManager.default

        if let cacheDir = recordingsManager.cacheDirectory {
            testCacheDirectory = cacheDir
        }
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    func testCacheDirectoryExists() {
        XCTAssertNotNil(recordingsManager.cacheDirectory)
    }

    func testRecordingsArrayIsInitialized() {
        XCTAssertNotNil(recordingsManager.recordings)
    }

    func testTranscriptionsDictionaryIsInitialized() {
        XCTAssertNotNil(recordingsManager.transcriptions)
    }

    func testScanForRecordingsFindsWavFiles() throws {
        let tempWavURL = testCacheDirectory.appendingPathComponent("test_recording.wav")
        fileManager.createFile(atPath: tempWavURL.path, contents: Data())

        recordingsManager.scanForRecordings()

        XCTAssertTrue(recordingsManager.recordings.contains(tempWavURL))

        try? fileManager.removeItem(at: tempWavURL)
    }

    func testScanForRecordingsIgnoresNonWavFiles() throws {
        let tempTxtURL = testCacheDirectory.appendingPathComponent("test_file.txt")
        fileManager.createFile(atPath: tempTxtURL.path, contents: Data())

        recordingsManager.scanForRecordings()

        XCTAssertFalse(recordingsManager.recordings.contains(tempTxtURL))

        try? fileManager.removeItem(at: tempTxtURL)
    }

    func testScanForRecordingsSortsByNewestFirst() throws {
        let olderWavURL = testCacheDirectory.appendingPathComponent("older_recording.wav")
        fileManager.createFile(atPath: olderWavURL.path, contents: Data())

        Thread.sleep(forTimeInterval: 0.1)

        let newerWavURL = testCacheDirectory.appendingPathComponent("newer_recording.wav")
        fileManager.createFile(atPath: newerWavURL.path, contents: Data())

        recordingsManager.scanForRecordings()

        if let newerIndex = recordingsManager.recordings.firstIndex(of: newerWavURL),
           let olderIndex = recordingsManager.recordings.firstIndex(of: olderWavURL) {
            XCTAssertLessThan(newerIndex, olderIndex)
        }

        try? fileManager.removeItem(at: olderWavURL)
        try? fileManager.removeItem(at: newerWavURL)
    }

    func testAddTranscriptionStoresTextForURL() {
        let testURL = URL(fileURLWithPath: "/tmp/test.wav")
        let transcriptionText = "Hello world"

        recordingsManager.addTranscription(for: testURL, text: transcriptionText)

        XCTAssertEqual(recordingsManager.transcriptions[testURL], transcriptionText)
    }

    func testAddTranscriptionUpdatesExistingTranscription() {
        let testURL = URL(fileURLWithPath: "/tmp/test.wav")
        let originalText = "Hello world"
        let updatedText = "Updated transcription"

        recordingsManager.addTranscription(for: testURL, text: originalText)
        recordingsManager.addTranscription(for: testURL, text: updatedText)

        XCTAssertEqual(recordingsManager.transcriptions[testURL], updatedText)
    }

    func testAddTranscriptionTriggersRescanIfURLNotInRecordings() throws {
        let testWavURL = testCacheDirectory.appendingPathComponent("new_recording.wav")
        fileManager.createFile(atPath: testWavURL.path, contents: Data())

        let initialCount = recordingsManager.recordings.count
        recordingsManager.addTranscription(for: testWavURL, text: "Test transcription")

        XCTAssertTrue(recordingsManager.recordings.contains(testWavURL))

        try? fileManager.removeItem(at: testWavURL)
    }
}
