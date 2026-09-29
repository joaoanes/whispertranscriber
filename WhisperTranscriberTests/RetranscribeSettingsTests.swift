import AVFoundation
import XCTest
@testable import WhisperTranscriber

@MainActor
final class RetranscribeSettingsTests: XCTestCase {

    private var originalSuffix = ""
    private var originalCleanup = true
    private var originalRemoveUm = false
    private var originalSpeakers = false
    private var audio: URL!

    override func setUp() async throws {
        try await super.setUp()
        let settings = SettingsManager.shared
        originalSuffix = settings.suffix
        originalCleanup = settings.cleanupEnabled
        originalRemoveUm = settings.removeUm
        originalSpeakers = settings.speakerDetectionEnabled
        settings.suffix = ""

        audio = FileManager.default.temporaryDirectory
            .appendingPathComponent("retranscribe-\(UUID().uuidString).wav")
        try writeSilentWav(to: audio)
    }

    override func tearDown() async throws {
        let settings = SettingsManager.shared
        settings.suffix = originalSuffix
        settings.cleanupEnabled = originalCleanup
        settings.removeUm = originalRemoveUm
        settings.speakerDetectionEnabled = originalSpeakers
        try? FileManager.default.removeItem(at: audio)
        try await super.tearDown()
    }

    private func writeSilentWav(to url: URL) throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_000)!
        buffer.frameLength = 16_000
        try file.write(from: buffer)
    }

    private func retranscribe(with engine: ScriptedEngine) async {
        let recorder = RecorderViewModel(engine: engine, capture: FakeAudioCapture(), prewarm: false)
        recorder.retranscribe(url: audio)
        await recorder.finalizeTask?.value
    }

    private func transcript() -> String? {
        RecordingsManager.shared.transcriptions[audio]
    }

    func testRetranscribeUsesThePlainPathWhenSpeakerDetectionIsOff() async {
        SettingsManager.shared.speakerDetectionEnabled = false
        let engine = ScriptedEngine(final: "uh some words here")

        await retranscribe(with: engine)

        let usedSpeakers = await engine.usedSpeakerPath
        XCTAssertFalse(usedSpeakers)
    }

    func testRetranscribeHonoursSpeakerDetectionWhenOn() async {
        SettingsManager.shared.speakerDetectionEnabled = true
        let engine = ScriptedEngine(final: "Speaker 1: hello")

        await retranscribe(with: engine)

        let usedSpeakers = await engine.usedSpeakerPath
        XCTAssertTrue(usedSpeakers, "retranscribe must respect the Detect Speakers toggle")
    }

    func testRetranscribeLeavesFillersAloneWhenCleanupIsOff() async {
        SettingsManager.shared.speakerDetectionEnabled = false
        SettingsManager.shared.cleanupEnabled = false

        await retranscribe(with: ScriptedEngine(final: "uh some words here"))

        XCTAssertEqual(transcript(), "uh some words here")
    }

    func testRetranscribeStripsFillersWhenCleanupIsOn() async {
        SettingsManager.shared.speakerDetectionEnabled = false
        SettingsManager.shared.cleanupEnabled = true
        SettingsManager.shared.removeUm = false

        await retranscribe(with: ScriptedEngine(final: "uh some words here"))

        XCTAssertEqual(transcript(), "Some words here")
    }

    func testRetranscribeAppliesTheUmSettingLikeTheRecordingPath() async {
        SettingsManager.shared.speakerDetectionEnabled = false
        SettingsManager.shared.cleanupEnabled = true
        SettingsManager.shared.removeUm = true

        await retranscribe(with: ScriptedEngine(final: "um some words here"))

        XCTAssertEqual(transcript(), "Some words here")
    }

    func testRetranscribeTrimsSilenceLikeTheRecordingPath() async {
        SettingsManager.shared.speakerDetectionEnabled = false
        let engine = ScriptedEngine(final: "ignored")
        let recorder = RecorderViewModel(engine: engine, capture: FakeAudioCapture(), prewarm: false)

        recorder.retranscribe(url: audio)
        await recorder.finalizeTask?.value

        let counts = await engine.transcribedSampleCounts
        XCTAssertEqual(counts.count, 1, "retranscribe should run exactly one pass over the trimmed audio")
    }
}
