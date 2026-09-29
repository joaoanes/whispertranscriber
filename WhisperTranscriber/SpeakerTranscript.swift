import Foundation

struct TimedWord: Equatable {
    let word: String
    let start: TimeInterval
    let end: TimeInterval

    var midpoint: TimeInterval { (start + end) / 2 }
}

struct SpeakerSpan: Equatable {
    let speakerId: String
    let start: TimeInterval
    let end: TimeInterval

    func contains(_ time: TimeInterval) -> Bool {
        time >= start && time <= end
    }

    func distance(to time: TimeInterval) -> TimeInterval {
        contains(time) ? 0 : min(abs(start - time), abs(end - time))
    }
}

enum SpeakerTranscript {
    static func format(words: [TimedWord], speakers: [SpeakerSpan]) -> String {
        guard !words.isEmpty else { return "" }
        guard !speakers.isEmpty else { return plainText(from: words) }

        let labelled = words.map { word in
            (label: label(for: speaker(of: word, among: speakers)), word: word.word)
        }

        return grouped(labelled)
            .map { "\($0.label): \($0.words.joined(separator: " "))" }
            .joined(separator: "\n")
    }

    private static func plainText(from words: [TimedWord]) -> String {
        words.map(\.word).joined(separator: " ")
    }

    private static func speaker(of word: TimedWord, among speakers: [SpeakerSpan]) -> String {
        let nearest = speakers.min {
            $0.distance(to: word.midpoint) < $1.distance(to: word.midpoint)
        }
        return nearest?.speakerId ?? ""
    }

    private static func label(for speakerId: String) -> String {
        speakerId.lowercased().hasPrefix("speaker") ? speakerId : "Speaker \(speakerId)"
    }

    private static func grouped(
        _ labelled: [(label: String, word: String)]
    ) -> [(label: String, words: [String])] {
        labelled.reduce(into: [(label: String, words: [String])]()) { turns, entry in
            if turns.last?.label == entry.label {
                turns[turns.count - 1].words.append(entry.word)
            } else {
                turns.append((label: entry.label, words: [entry.word]))
            }
        }
    }
}
