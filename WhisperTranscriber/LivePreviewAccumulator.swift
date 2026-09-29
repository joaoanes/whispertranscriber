import Foundation

struct LivePreviewAccumulator {
    private(set) var committed = 0
    private(set) var text = ""

    mutating func claimSegment(upTo boundary: Int, capturedCount: Int) -> Range<Int>? {
        guard boundary > committed, boundary <= capturedCount else { return nil }
        let segment = committed..<boundary
        committed = boundary
        return segment
    }

    mutating func append(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        text = text.isEmpty ? trimmed : text + " " + trimmed
    }

    mutating func reset() {
        committed = 0
        text = ""
    }
}
