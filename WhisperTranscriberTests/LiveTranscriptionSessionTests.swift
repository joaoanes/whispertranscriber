import XCTest
@testable import WhisperTranscriber

final class LiveTranscriptionSessionTests: XCTestCase {

    private func session(
        boundaries: [Int] = [],
        partials: [String],
        timing: LiveTranscriptionTiming
    ) async -> (LiveTranscriptionSession, ScriptedEngine) {
        let engine = ScriptedEngine(boundaries: boundaries, partials: partials)
        let session = LiveTranscriptionSession(engine: engine, timing: timing)
        await session.begin()
        return (session, engine)
    }

    private func feed(
        _ session: LiveTranscriptionSession,
        chunks: Int,
        of size: Int = 16_000
    ) async -> [[LiveSegment]?] {
        var captured: [Float] = []
        var results: [[LiveSegment]?] = []
        for _ in 0..<chunks {
            let chunk = [Float](repeating: 0.1, count: size)
            captured += chunk
            results.append(await session.consume(chunk, captured: captured))
        }
        return results
    }

    func testAPauseCommitsTheUtteranceSinceTheLastPause() async {
        let (session, engine) = await session(
            boundaries: [16_000],
            partials: ["Hello there."],
            timing: .pausesOnly
        )

        let results = await feed(session, chunks: 1)

        XCTAssertEqual(results.last ?? nil, [LiveSegment(startsAt: 0, text: "Hello there.")])
        XCTAssertEqual(session.committed, [LiveSegment(startsAt: 0, text: "Hello there.")])
        let transcribed = await engine.transcribedSampleCounts
        XCTAssertEqual(transcribed, [16_000])
    }

    func testTheOpenUtteranceIsRetranscribedWholeSoEarlierGuessesAreReplaced() async {
        let (session, engine) = await session(
            partials: ["This isn't how you started.", "This isn't how you start a studio."],
            timing: LiveTranscriptionTiming(tailRefreshSamples: 16_000, maxUncommittedSamples: .max)
        )

        let results = await feed(session, chunks: 2)

        XCTAssertEqual(results.last ?? nil, [LiveSegment(startsAt: 0, text: "This isn't how you start a studio.")])
        XCTAssertEqual(session.committed, [], "an unfinished utterance is never committed")
        let transcribed = await engine.transcribedSampleCounts
        XCTAssertEqual(transcribed, [16_000, 32_000], "each refresh covers the whole open utterance")
    }

    func testEachUtteranceKeepsTheTimeItStarted() async {
        let (session, _) = await session(
            boundaries: [16_000, 48_000],
            partials: ["One.", "Two."],
            timing: .pausesOnly
        )

        _ = await feed(session, chunks: 3)

        XCTAssertEqual(session.committed, [
            LiveSegment(startsAt: 0, text: "One."),
            LiveSegment(startsAt: 1, text: "Two.")
        ])
    }

    func testAMonologueWithoutPausesIsCommittedBeforeItOutgrowsTheModel() async {
        let (session, _) = await session(
            partials: ["A very long monologue."],
            timing: LiveTranscriptionTiming(tailRefreshSamples: .max, maxUncommittedSamples: 32_000)
        )

        let results = await feed(session, chunks: 2)

        XCTAssertNil(results[0] ?? nil)
        XCTAssertEqual(session.committed, [LiveSegment(startsAt: 0, text: "A very long monologue.")])
    }

    func testNothingIsReportedBetweenRefreshes() async {
        let (session, engine) = await session(
            partials: ["Unused."],
            timing: .pausesOnly
        )

        let results = await feed(session, chunks: 3)

        XCTAssertTrue(results.allSatisfy { $0 == nil })
        let transcribed = await engine.transcribedSampleCounts
        XCTAssertEqual(transcribed, [])
    }
}
