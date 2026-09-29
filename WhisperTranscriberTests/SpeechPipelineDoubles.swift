import Foundation
@testable import WhisperTranscriber

final class FakeAudioCapture: AudioCapturing, @unchecked Sendable {
    var scriptedSamples: [Float] = []
    var chunkSize = 1365

    private(set) var samples: [Float] = []
    private(set) var emittedChunks: Bool?
    private var continuation: AsyncStream<[Float]>.Continuation?

    func start(writingTo url: URL, emittingChunks: Bool) throws -> AsyncStream<[Float]>? {
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
    private let boundaries: [Int]
    private let partials: [String]
    private let final: String

    private var processed = 0
    private var nextBoundary = 0
    private var nextPartial = 0
    private var finalizing = false

    private(set) var boundaryChecks = 0
    private(set) var usedSpeakerPath = false
    private(set) var transcribedSampleCounts: [Int] = []

    init(boundaries: [Int] = [], partials: [String] = [], final: String = "Final transcript.") {
        self.boundaries = boundaries
        self.partials = partials
        self.final = final
    }

    func prepare(progressCallback: @escaping @Sendable (Double) -> Void) async throws {
        progressCallback(1.0)
    }

    func unload() async {}

    func resetSpeechBoundaries() async {
        processed = 0
        nextBoundary = 0
    }

    func speechEndIndex(in chunk: [Float]) async throws -> Int? {
        boundaryChecks += 1
        processed += chunk.count
        guard nextBoundary < boundaries.count, processed >= boundaries[nextBoundary] else { return nil }
        let boundary = boundaries[nextBoundary]
        nextBoundary += 1
        return boundary
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
        guard !finalizing else { return final }
        guard nextPartial < partials.count else { return "" }
        let partial = partials[nextPartial]
        nextPartial += 1
        return partial
    }
}
