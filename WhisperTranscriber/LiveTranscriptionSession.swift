import Foundation

struct LiveSegment: Equatable {
    let startsAt: TimeInterval
    let text: String
}

extension Array where Element == LiveSegment {
    var text: String {
        map(\.text).joined(separator: " ")
    }
}

extension String {
    var sentences: [String] {
        var sentences: [String] = []
        enumerateSubstrings(in: startIndex..<endIndex, options: .bySentences) { sentence, _, _, _ in
            guard let trimmed = sentence?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty
            else { return }
            sentences.append(trimmed)
        }
        return sentences
    }
}

struct LiveTranscriptionTiming {
    let tailRefreshSamples: Int
    let maxUncommittedSamples: Int

    static let standard = LiveTranscriptionTiming(
        tailRefreshSamples: Int(1.5 * AudioCapture.sampleRate),
        maxUncommittedSamples: Int(14 * AudioCapture.sampleRate)
    )

    static let pausesOnly = LiveTranscriptionTiming(
        tailRefreshSamples: .max,
        maxUncommittedSamples: .max
    )
}

final class LiveTranscriptionSession {
    private let engine: SpeechTranscribing
    private let timing: LiveTranscriptionTiming

    private(set) var committed: [LiveSegment] = []
    private var committedSampleCount = 0
    private var lastRefreshAt = 0

    init(engine: SpeechTranscribing, timing: LiveTranscriptionTiming) {
        self.engine = engine
        self.timing = timing
    }

    func begin() async {
        await engine.resetSpeechBoundaries()
    }

    func consume(_ chunk: [Float], captured: [Float]) async -> [LiveSegment]? {
        let boundary = try? await engine.speechEndIndex(in: chunk)

        if let boundary, boundary > committedSampleCount, boundary <= captured.count {
            await commit(captured, upTo: boundary)
            return committed
        }

        let uncommitted = captured.count - committedSampleCount
        if uncommitted >= timing.maxUncommittedSamples {
            await commit(captured, upTo: captured.count)
            return committed
        }

        guard captured.count - lastRefreshAt >= timing.tailRefreshSamples else { return nil }
        lastRefreshAt = captured.count
        let tail = await transcribe(captured[committedSampleCount..<captured.count])
        return committed + segments(of: tail, startingAt: committedSampleCount)
    }

    private func commit(_ captured: [Float], upTo boundary: Int) async {
        let text = await transcribe(captured[committedSampleCount..<boundary])
        committed += segments(of: text, startingAt: committedSampleCount)
        committedSampleCount = boundary
        lastRefreshAt = boundary
    }

    private func transcribe(_ samples: ArraySlice<Float>) async -> String {
        (try? await engine.transcribe(Array(samples))) ?? ""
    }

    private func segments(of text: String, startingAt sample: Int) -> [LiveSegment] {
        let startsAt = Double(sample) / AudioCapture.sampleRate
        return text.sentences.map { LiveSegment(startsAt: startsAt, text: $0) }
    }
}
