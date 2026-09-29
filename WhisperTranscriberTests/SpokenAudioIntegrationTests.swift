import XCTest
@testable import WhisperTranscriber

@MainActor
final class SpokenAudioIntegrationTests: XCTestCase {

    private var originalSuffix = ""

    override func setUp() async throws {
        try await super.setUp()
        originalSuffix = SettingsManager.shared.suffix
        SettingsManager.shared.suffix = ""
    }

    override func tearDown() async throws {
        SettingsManager.shared.suffix = originalSuffix
        try await super.tearDown()
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "SpokenAudio",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "\(tool) failed"]
            )
        }
    }

    static func speak(_ phrase: String, voice: String? = nil) throws -> [Float] {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoken-\(UUID().uuidString)")
        let aiff = base.appendingPathExtension("aiff")
        let wav = base.appendingPathExtension("wav")

        let voiceArguments = voice.map { ["-v", $0] } ?? []
        try run("/usr/bin/say", voiceArguments + ["-o", aiff.path, phrase])
        try run("/usr/bin/afconvert", [
            "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", aiff.path, wav.path
        ])

        defer {
            try? FileManager.default.removeItem(at: aiff)
            try? FileManager.default.removeItem(at: wav)
        }
        return try AudioCapture.loadSamples(from: wav)
    }

    private func requireModels() throws {
        guard let models = getModelsDirectory()?
            .appendingPathComponent(ParakeetModelLoader.asrFolderName),
            FileManager.default.fileExists(atPath: models.path)
        else {
            throw XCTSkip("Parakeet models not installed; run the app once to download them.")
        }
    }

    func testSpokenAudioTranscribesThroughTheRealEngine() async throws {
        try requireModels()

        let engine = ParakeetEngine()
        try await engine.prepare { _ in }

        let samples = try Self.speak("The quick brown fox jumps over the lazy dog.")
        let speech = try await engine.speechOnly(samples)
        let text = try await engine.transcribe(speech)

        XCTAssertTrue(
            text.lowercased().contains("quick brown fox"),
            "expected the spoken phrase, got: \(text)"
        )
    }

    /// Speaker separation itself is not asserted here. Synthetic `say` voices produce
    /// embeddings too similar for the shipped clustering threshold — 8 of 10 voice pairs
    /// merge into one speaker — so a two-speaker assertion would be testing the fixture,
    /// not the feature. Validating real separation needs recordings of real people.
    func testMultiVoiceAudioSurvivesTheSpeakerPathIntact() async throws {
        try requireModels()

        let engine = ParakeetEngine()
        try await engine.prepare { _ in }

        let first = try Self.speak(
            "Good morning, I wanted to talk about the quarterly report today.",
            voice: "Karen"
        )
        let second = try Self.speak(
            "Certainly, I have the numbers ready for you right here.",
            voice: "Albert"
        )
        let conversation = first + [Float](repeating: 0, count: 8_000) + second

        let transcript = try await engine.transcribeWithSpeakers(conversation)

        XCTAssertTrue(
            transcript.lowercased().contains("quarterly"),
            "both utterances must survive diarization, got: \(transcript)"
        )
        XCTAssertTrue(
            transcript.lowercased().contains("numbers"),
            "both utterances must survive diarization, got: \(transcript)"
        )
        XCTAssertTrue(
            transcript.hasPrefix("Speaker "),
            "output must be in labelled-turn form, got: \(transcript)"
        )
    }

    func testSingleVoiceProducesExactlyOneLabelledTurn() async throws {
        try requireModels()

        let engine = ParakeetEngine()
        try await engine.prepare { _ in }

        let samples = try Self.speak(
            "This is one person speaking continuously for a short while about nothing in particular.",
            voice: "Samantha"
        )

        let transcript = try await engine.transcribeWithSpeakers(samples)
        let labels = Set(
            transcript.split(separator: "\n").compactMap { $0.split(separator: ":").first.map(String.init) }
        )

        XCTAssertEqual(labels.count, 1, "one voice should not be split across speakers, got: \(transcript)")
        XCTAssertTrue(
            transcript.hasPrefix("Speaker "),
            "word timings must be available so turns are labelled rather than falling back to plain text"
        )
    }

    func testSilenceIsTrimmedToNothingByVAD() async throws {
        try requireModels()

        let engine = ParakeetEngine()
        try await engine.prepare { _ in }

        let speech = try await engine.speechOnly([Float](repeating: 0, count: 16_000 * 3))

        XCTAssertTrue(speech.isEmpty, "three seconds of silence should yield no speech audio")
    }

    func testLiveModeTranscribesSpokenAudioEndToEnd() async throws {
        try requireModels()

        SettingsManager.shared.liveTranscriptionEnabled = true
        let engine = ParakeetEngine()
        try await engine.prepare { _ in }

        let capture = FakeAudioCapture()
        capture.scriptedSamples = try Self.speak(
            "First I open the popover. [[slnc 1200]] Then it lands on the clipboard."
        )
        let recorder = RecorderViewModel(engine: engine, capture: capture, prewarm: false)

        recorder.beginRecorder()
        recorder.stopRecording()
        await recorder.finalizeTask?.value

        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        XCTAssertTrue(
            clipboard.lowercased().contains("popover") && clipboard.lowercased().contains("clipboard"),
            "expected the full spoken transcript on the clipboard, got: \(clipboard)"
        )
    }
}
