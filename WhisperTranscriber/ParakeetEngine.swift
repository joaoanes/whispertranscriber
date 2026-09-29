import FluidAudio
import Foundation

enum ParakeetEngineError: LocalizedError {
    case notReady

    var errorDescription: String? {
        switch self {
        case .notReady:
            return "Speech engine is not ready yet."
        }
    }
}

actor ParakeetEngine {
    private var asr: AsrManager?
    private var vad: VadManager?
    private var diarizer: DiarizerManager?
    private var decoderLayers = 2
    private var streamState: VadStreamState?

    var isReady: Bool { asr != nil }

    func prepare(progressCallback: @escaping @Sendable (Double) -> Void) async throws {
        let models = try await ParakeetModelLoader.loadASR(progressCallback: progressCallback)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        decoderLayers = models.version.decoderLayers
        asr = manager
        vad = try await ParakeetModelLoader.loadVAD()
    }

    func unload() {
        asr = nil
        vad = nil
        diarizer?.cleanup()
        diarizer = nil
        streamState = nil
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        guard let asr else { throw ParakeetEngineError.notReady }
        guard !samples.isEmpty else { return "" }
        var state = try TdtDecoderState(decoderLayers: decoderLayers)
        return try await asr.transcribe(samples, decoderState: &state).text
    }

    func transcribeWithSpeakers(_ samples: [Float]) async throws -> String {
        guard let asr else { throw ParakeetEngineError.notReady }
        guard !samples.isEmpty else { return "" }

        var state = try TdtDecoderState(decoderLayers: decoderLayers)
        let result = try await asr.transcribe(samples, decoderState: &state)

        guard let timings = result.tokenTimings, !timings.isEmpty else {
            Log.speech.info("⚠️ No word timings available, falling back to plain transcript")
            return result.text
        }

        let words = buildWordTimings(from: timings).map {
            TimedWord(word: $0.word, start: $0.startTime, end: $0.endTime)
        }
        let spans = try await speakerSpans(in: samples)
        Log.speech.info("🗣️ Detected \(Set(spans.map(\.speakerId)).count) speaker(s)")

        return SpeakerTranscript.format(words: words, speakers: spans)
    }

    private func speakerSpans(in samples: [Float]) async throws -> [SpeakerSpan] {
        let manager = try await ensureDiarizer()
        return try manager.performCompleteDiarization(samples).segments.map {
            SpeakerSpan(
                speakerId: $0.speakerId,
                start: TimeInterval($0.startTimeSeconds),
                end: TimeInterval($0.endTimeSeconds)
            )
        }
    }

    private func ensureDiarizer() async throws -> DiarizerManager {
        if let diarizer { return diarizer }
        let models = try await ParakeetModelLoader.loadDiarizer { _ in }
        let manager = DiarizerManager()
        manager.initialize(models: models)
        diarizer = manager
        return manager
    }

    func speechOnly(_ samples: [Float]) async throws -> [Float] {
        guard let vad else { return samples }
        return try await vad.segmentSpeechAudio(samples).flatMap { $0 }
    }

    func resetSpeechBoundaries() async {
        guard let vad else { return }
        streamState = await vad.makeStreamState()
    }

    func speechEndIndex(in chunk: [Float]) async throws -> Int? {
        guard let vad, let state = streamState else { return nil }
        let result = try await vad.processStreamingChunk(chunk, state: state)
        streamState = result.state
        guard let event = result.event, event.isEnd else { return nil }
        return event.sampleIndex
    }
}
