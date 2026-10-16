import CoreAudio
import Foundation
@testable import WhisperTranscriber

final class FakeAudioCapture: AudioCapturing, @unchecked Sendable {
    var scriptedSamples: [Float] = []
    var chunkSize = 1365

    private(set) var samples: [Float] = []
    private(set) var emittedChunks: Bool?
    private var continuation: AsyncStream<[Float]>.Continuation?

    func start(writingTo url: URL, emittingChunks: Bool, inputDevice: AudioDeviceID?) throws -> AsyncStream<[Float]>? {
        samples = []
        emittedChunks = emittingChunks

        guard emittingChunks else {
            samples = scriptedSamples
            return nil
        }

        return AsyncStream { continuation in
            self.continuation = continuation
            for start in stride(from: 0, to: scriptedSamples.count, by: chunkSize) {
                let chunk = Array(scriptedSamples[start..<min(start + chunkSize, scriptedSamples.count)])
                samples.append(contentsOf: chunk)
                continuation.yield(chunk)
            }
        }
    }

    func stop() {
        continuation?.finish()
        continuation = nil
    }
}

actor ScriptedEngine: SpeechTranscribing {
    private let partials: [String]
    private let partialEvery: Int
    private let final: String

    private var fed = 0
    private var nextPartial = 0
    private var finalizing = false
    private var liveContinuation: AsyncStream<LiveTranscriptChunk>.Continuation?

    private(set) var liveSessions = 0
    private(set) var fedSampleCount = 0
    private(set) var usedSpeakerPath = false
    private(set) var transcribedSampleCounts: [Int] = []

    init(partials: [String] = [], partialEvery: Int = 16_000, final: String = "Final transcript.") {
        self.partials = partials
        self.partialEvery = partialEvery
        self.final = final
    }

    func prepare(progressCallback: @escaping @Sendable (Double) -> Void) async throws {
        progressCallback(1.0)
    }

    func unload() async {}

    func startLiveTranscription() async throws -> AsyncStream<LiveTranscriptChunk> {
        liveSessions += 1
        fed = 0
        let (stream, continuation) = AsyncStream<LiveTranscriptChunk>.makeStream()
        liveContinuation = continuation
        return stream
    }

    func feedLive(_ samples: [Float]) async {
        fedSampleCount += samples.count
        fed += samples.count
        while nextPartial < partials.count, fed >= partialEvery * (nextPartial + 1) {
            liveContinuation?.yield(LiveTranscriptChunk(
                text: partials[nextPartial],
                startsAt: Double(partialEvery * nextPartial) / AudioCapture.sampleRate
            ))
            nextPartial += 1
        }
    }

    func finishLiveTranscription() async {
        liveContinuation?.finish()
        liveContinuation = nil
    }

    func speechOnly(_ samples: [Float]) async throws -> [Float] {
        finalizing = true
        return samples
    }

    func transcribeWithSpeakers(_ samples: [Float]) async throws -> String {
        usedSpeakerPath = true
        return try await transcribe(samples)
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        transcribedSampleCounts.append(samples.count)
        return final
    }
}
