import XCTest
@testable import WhisperTranscriber

final class SpeakerTranscriptTests: XCTestCase {

    private func words(_ pairs: [(String, TimeInterval, TimeInterval)]) -> [TimedWord] {
        pairs.map { TimedWord(word: $0.0, start: $0.1, end: $0.2) }
    }

    func testLabelsEachTurnAndGroupsConsecutiveWords() {
        let spoken = words([("Hello", 0, 0.5), ("there", 0.5, 1.0), ("Hi", 2.0, 2.5), ("back", 2.5, 3.0)])
        let speakers = [
            SpeakerSpan(speakerId: "1", start: 0, end: 1.2),
            SpeakerSpan(speakerId: "2", start: 1.8, end: 3.2)
        ]

        XCTAssertEqual(
            SpeakerTranscript.format(words: spoken, speakers: speakers),
            "Speaker 1: Hello there\nSpeaker 2: Hi back"
        )
    }

    func testAlternatingSpeakersProduceSeparateTurns() {
        let spoken = words([("A", 0, 0.4), ("B", 1.0, 1.4), ("C", 2.0, 2.4)])
        let speakers = [
            SpeakerSpan(speakerId: "1", start: 0, end: 0.5),
            SpeakerSpan(speakerId: "2", start: 0.9, end: 1.5),
            SpeakerSpan(speakerId: "1", start: 1.9, end: 2.5)
        ]

        XCTAssertEqual(
            SpeakerTranscript.format(words: spoken, speakers: speakers),
            "Speaker 1: A\nSpeaker 2: B\nSpeaker 1: C"
        )
    }

    func testWordOutsideEverySpanIsAttributedToTheNearestSpeaker() {
        let spoken = words([("stray", 5.0, 5.4)])
        let speakers = [
            SpeakerSpan(speakerId: "1", start: 0, end: 1.0),
            SpeakerSpan(speakerId: "2", start: 4.0, end: 4.5)
        ]

        XCTAssertEqual(SpeakerTranscript.format(words: spoken, speakers: speakers), "Speaker 2: stray")
    }

    func testFallsBackToPlainTextWhenNoSpeakersWereDetected() {
        let spoken = words([("just", 0, 0.4), ("me", 0.4, 0.8)])

        XCTAssertEqual(SpeakerTranscript.format(words: spoken, speakers: []), "just me")
    }

    func testEmptyWordsProduceEmptyTranscript() {
        XCTAssertEqual(
            SpeakerTranscript.format(words: [], speakers: [SpeakerSpan(speakerId: "1", start: 0, end: 1)]),
            ""
        )
    }

    func testDoesNotDoublePrefixSpeakerIdsThatAreAlreadyLabelled() {
        let spoken = words([("hi", 0, 0.4)])
        let speakers = [SpeakerSpan(speakerId: "Speaker 3", start: 0, end: 1)]

        XCTAssertEqual(SpeakerTranscript.format(words: spoken, speakers: speakers), "Speaker 3: hi")
    }

    func testSingleSpeakerProducesOneTurn() {
        let spoken = words([("one", 0, 0.4), ("long", 0.4, 0.8), ("turn", 0.8, 1.2)])
        let speakers = [SpeakerSpan(speakerId: "1", start: 0, end: 2)]

        XCTAssertEqual(SpeakerTranscript.format(words: spoken, speakers: speakers), "Speaker 1: one long turn")
    }
}
