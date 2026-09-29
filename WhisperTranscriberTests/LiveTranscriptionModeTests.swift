import XCTest
@testable import WhisperTranscriber

@MainActor
final class LiveTranscriptionModeTests: XCTestCase {

    private var originalSuffix = ""
    private var originalCleanup = true
    private var originalLive = true

    override func setUp() async throws {
        try await super.setUp()
        originalSuffix = SettingsManager.shared.suffix
        originalCleanup = SettingsManager.shared.cleanupEnabled
        originalLive = SettingsManager.shared.liveTranscriptionEnabled
        SettingsManager.shared.suffix = ""
        SettingsManager.shared.cleanupEnabled = true
    }

    override func tearDown() async throws {
        SettingsManager.shared.suffix = originalSuffix
        SettingsManager.shared.cleanupEnabled = originalCleanup
        SettingsManager.shared.liveTranscriptionEnabled = originalLive
        try await super.tearDown()
    }

    private func makeRecorder(
        boundaries: [Int],
        partials: [String],
        final: String,
        sampleCount: Int
    ) -> (RecorderViewModel, FakeAudioCapture, ScriptedEngine) {
        let engine = ScriptedEngine(boundaries: boundaries, partials: partials, final: final)
        let capture = FakeAudioCapture()
        capture.scriptedSamples = [Float](repeating: 0.1, count: sampleCount)
        let recorder = RecorderViewModel(engine: engine, capture: capture, prewarm: false)
        return (recorder, capture, engine)
    }

    private func waitFor(
        _ description: String,
        timeout: TimeInterval = 5,
        until condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for \(description)")
    }

    func testLiveOnAccumulatesPartialsIntoThePopoverAndTheRecord() async throws {
        SettingsManager.shared.liveTranscriptionEnabled = true
        let (recorder, capture, engine) = makeRecorder(
            boundaries: [16_000, 32_000],
            partials: ["First phrase.", "Second phrase."],
            final: "First phrase. Second phrase.",
            sampleCount: 48_000
        )

        recorder.beginRecorder()

        try await waitFor("both partials to land") {
            recorder.livePreview == "First phrase. Second phrase."
        }

        let emitted = await engine.transcribedSampleCounts
        XCTAssertEqual(emitted, [16_000, 16_000], "each partial should cover only its own new audio")
        XCTAssertEqual(capture.emittedChunks, true)

        recorder.stopRecording()
        await recorder.finalizeTask?.value

        XCTAssertEqual(
            RecordingsManager.shared.transcriptions.values.first { $0.contains("First phrase.") },
            "First phrase. Second phrase."
        )
    }

    func testLiveOffRunsNoInferenceUntilTheRecordingStops() async throws {
        SettingsManager.shared.liveTranscriptionEnabled = false
        let (recorder, capture, engine) = makeRecorder(
            boundaries: [16_000, 32_000],
            partials: ["Should never appear."],
            final: "Only the final transcript.",
            sampleCount: 48_000
        )

        recorder.beginRecorder()

        XCTAssertEqual(capture.emittedChunks, false, "capture must not emit chunks when live is off")

        let checksWhileRecording = await engine.boundaryChecks
        XCTAssertEqual(checksWhileRecording, 0, "VAD must not run while live transcription is off")
        XCTAssertEqual(recorder.livePreview, "")

        recorder.stopRecording()
        await recorder.finalizeTask?.value

        let checksAfterStop = await engine.boundaryChecks
        XCTAssertEqual(checksAfterStop, 0)

        let emitted = await engine.transcribedSampleCounts
        XCTAssertEqual(emitted, [48_000], "exactly one pass, over the whole recording")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Only the final transcript.")
    }

    func testChoiceIsLockedInForTheWholeRecording() async throws {
        SettingsManager.shared.liveTranscriptionEnabled = false
        let (recorder, capture, engine) = makeRecorder(
            boundaries: [16_000],
            partials: ["Should never appear."],
            final: "Final.",
            sampleCount: 32_000
        )

        recorder.beginRecorder()
        SettingsManager.shared.liveTranscriptionEnabled = true

        recorder.stopRecording()
        await recorder.finalizeTask?.value

        XCTAssertEqual(capture.emittedChunks, false)
        let checks = await engine.boundaryChecks
        XCTAssertEqual(checks, 0, "flipping the toggle mid-recording must not start live transcription")
        XCTAssertEqual(recorder.livePreview, "")
    }

    func testFinalTranscriptReplacesThePartialsInTheRecord() async throws {
        SettingsManager.shared.liveTranscriptionEnabled = true
        let (recorder, _, _) = makeRecorder(
            boundaries: [16_000],
            partials: ["Rough partial."],
            final: "Corrected final transcript.",
            sampleCount: 32_000
        )

        recorder.beginRecorder()
        try await waitFor("the partial to land") { recorder.livePreview == "Rough partial." }

        recorder.stopRecording()
        await recorder.finalizeTask?.value

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Corrected final transcript.")
        XCTAssertEqual(recorder.livePreview, "", "popover clears once the final transcript lands")
    }

    func testEmptyRecordingIsDroppedInsteadOfTranscribed() async throws {
        SettingsManager.shared.liveTranscriptionEnabled = false
        let engine = SilentEngine()
        let capture = FakeAudioCapture()
        capture.scriptedSamples = [Float](repeating: 0, count: 32_000)
        let recorder = RecorderViewModel(engine: engine, capture: capture, prewarm: false)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("untouched", forType: .string)

        recorder.beginRecorder()
        recorder.stopRecording()
        await recorder.finalizeTask?.value

        XCTAssertEqual(
            NSPasteboard.general.string(forType: .string),
            "untouched",
            "a recording with no speech must not overwrite the clipboard"
        )
    }
}

private actor SilentEngine: SpeechTranscribing {
    func prepare(progressCallback: @escaping @Sendable (Double) -> Void) async throws {}
    func unload() async {}
    func resetSpeechBoundaries() async {}
    func speechEndIndex(in chunk: [Float]) async throws -> Int? { nil }
    func speechOnly(_ samples: [Float]) async throws -> [Float] { [] }
    func transcribe(_ samples: [Float]) async throws -> String {
        XCTFail("transcribe must not be called when VAD finds no speech")
        return ""
    }
    func transcribeWithSpeakers(_ samples: [Float]) async throws -> String {
        XCTFail("transcribeWithSpeakers must not be called when VAD finds no speech")
        return ""
    }
}
