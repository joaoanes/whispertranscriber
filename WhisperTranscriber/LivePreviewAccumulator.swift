import Foundation

struct LiveSegment: Equatable, Identifiable {
    let startsAt: TimeInterval
    let text: String

    var id: TimeInterval { startsAt }
}

extension Array where Element == LiveSegment {
    var text: String {
        map(\.text).joined(separator: " ")
    }
}

struct LivePreviewAccumulator {
    private(set) var committed = 0
    private(set) var segments: [LiveSegment] = []

    var text: String { segments.text }

    mutating func claimSegment(upTo boundary: Int, capturedCount: Int) -> Range<Int>? {
        guard boundary > committed, boundary <= capturedCount else { return nil }
        let segment = committed..<boundary
        committed = boundary
        return segment
    }

    mutating func append(_ transcript: String, startingAt startsAt: TimeInterval) {
        let trimmed = transcript.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        segments.append(LiveSegment(startsAt: startsAt, text: trimmed))
    }

    mutating func reset() {
        committed = 0
        segments = []
    }
}
