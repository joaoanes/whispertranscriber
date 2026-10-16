import AVFoundation
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

struct LiveTranscriptChunk: Equatable, Sendable {
    let text: String
    let startsAt: TimeInterval
}

private struct LiveSession {
    let manager: SlidingWindowAsrManager
    let forwarding: Task<Void, Never>
    let continuation: AsyncStream<LiveTranscriptChunk>.Continuation
}

actor ParakeetEngine {
    static let liveConfig = SlidingWindowAsrConfig(
        chunkSeconds: 2.0,
        hypothesisChunkSeconds: 1.0,
        leftContextSeconds: 11.0,
        rightContextSeconds: 2.0,
        minContextForConfirmation: 10.0,
        confirmationThreshold: 0.85
    )

    private var models: AsrModels?
    private var asr: AsrManager?
    private var vad: VadManager?
    private var diarizer: DiarizerManager?
    private var decoderLayers = 2
    private var live: LiveSession?

    var isReady: Bool { asr != nil }

    func prepare(progressCallback: @escaping @Sendable (Double) -> Void) async throws {
        let models = try await ParakeetModelLoader.loadASR(progressCallback: progressCallback)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        decoderLayers = models.version.decoderLayers
        self.models = models
        asr = manager
        vad = try await ParakeetModelLoader.loadVAD()
    }

    func unload() async {
        await finishLiveTranscription()
        models = nil
        asr = nil
        vad = nil
        diarizer?.cleanup()
        diarizer = nil
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

    func startLiveTranscription() async throws -> AsyncStream<LiveTranscriptChunk> {
        guard let models else { throw ParakeetEngineError.notReady }
        await finishLiveTranscription()

        let manager = SlidingWindowAsrManager(config: Self.liveConfig)
        try await manager.loadModels(models)
        try await manager.startStreaming(source: .microphone)
        let updates = await manager.transcriptionUpdates

        let (stream, continuation) = AsyncStream<LiveTranscriptChunk>.makeStream()
        let forwarding = Task {
            for await update in updates {
                let text = update.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                continuation.yield(LiveTranscriptChunk(
                    text: text,
                    startsAt: update.tokenTimings.first?.startTime ?? 0
                ))
            }
        }
        live = LiveSession(manager: manager, forwarding: forwarding, continuation: continuation)
        return stream
    }

    func feedLive(_ samples: [Float]) async {
        guard let live, let buffer = Self.pcmBuffer(from: samples) else { return }
        await live.manager.streamAudio(buffer)
    }

    func finishLiveTranscription() async {
        guard let session = live else { return }
        live = nil
        session.continuation.finish()
        session.forwarding.cancel()
        await session.manager.cancel()
    }

    private static func pcmBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let format = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: AudioCapture.sampleRate,
                  channels: 1,
                  interleaved: false
              ),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel[0].update(from: base, count: samples.count)
        }
        return buffer
    }
}
