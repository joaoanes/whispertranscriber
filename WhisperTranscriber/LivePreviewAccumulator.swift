import Foundation

struct LiveSegment: Equatable {
    let startsAt: TimeInterval
    let text: String

    var endsSentence: Bool {
        text.last.map { ".?!…".contains($0) } ?? false
    }
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

struct LivePreviewAccumulator {
    private(set) var segments: [LiveSegment] = []

    var text: String { segments.text }

    mutating func append(_ transcript: String, startingAt startsAt: TimeInterval) {
        transcript.sentences.forEach { append(sentence: $0, startingAt: startsAt) }
    }

    mutating func reset() {
        segments = []
    }

    private mutating func append(sentence: String, startingAt startsAt: TimeInterval) {
        guard let last = segments.last, !last.endsSentence else {
            segments.append(LiveSegment(startsAt: startsAt, text: sentence))
            return
        }
        segments[segments.count - 1] = LiveSegment(startsAt: last.startsAt, text: last.text + " " + sentence)
    }
}
