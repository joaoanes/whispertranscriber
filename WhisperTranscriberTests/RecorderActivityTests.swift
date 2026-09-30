import XCTest
@testable import WhisperTranscriber

@MainActor
final class RecorderActivityTests: XCTestCase {

    private var originalLive = true

    override func setUp() async throws {
        try await super.setUp()
        originalLive = SettingsManager.shared.liveTranscriptionEnabled
        SettingsManager.shared.suffix = ""
    }

    override func tearDown() async throws {
        SettingsManager.shared.liveTranscriptionEnabled = originalLive
        try await super.tearDown()
    }

    private func makeRecorder() -> RecorderViewModel {
        let capture = FakeAudioCapture()
        capture.scriptedSamples = [Float](repeating: 0.1, count: 16_000)
        return RecorderViewModel(
            engine: ScriptedEngine(final: "done"),
            capture: capture,
            prewarm: false
        )
    }

    func testIdleBeforeAnythingHappens() {
        XCTAssertEqual(makeRecorder().activity, .idle)
    }

    func testRecordingWithLiveOffIsDistinctFromLiveOn() {
        SettingsManager.shared.liveTranscriptionEnabled = false
        let silent = makeRecorder()
        silent.beginRecorder()

        SettingsManager.shared.liveTranscriptionEnabled = true
        let live = makeRecorder()
        live.beginRecorder()

        XCTAssertEqual(silent.activity, .recording)
        XCTAssertEqual(live.activity, .recordingLive)
        XCTAssertNotEqual(silent.activity, live.activity)
    }

    func testActivityReturnsToIdleAfterTranscribing() async {
        SettingsManager.shared.liveTranscriptionEnabled = false
        let recorder = makeRecorder()

        recorder.beginRecorder()
        XCTAssertEqual(recorder.activity, .recording)

        recorder.stopRecording()
        await recorder.finalizeTask?.value

        XCTAssertEqual(recorder.activity, .idle)
    }

    func testLiveFlagIsCapturedAtRecordStartNotReadLive() {
        SettingsManager.shared.liveTranscriptionEnabled = true
        let recorder = makeRecorder()
        recorder.beginRecorder()

        SettingsManager.shared.liveTranscriptionEnabled = false

        XCTAssertEqual(
            recorder.activity,
            .recordingLive,
            "the icon must reflect the mode the recording started in"
        )
    }
}
