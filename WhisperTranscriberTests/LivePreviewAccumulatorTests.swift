import XCTest
@testable import WhisperTranscriber

final class LivePreviewAccumulatorTests: XCTestCase {

    func testAppendJoinsSegmentsWithASingleSpace() {
        var accumulator = LivePreviewAccumulator()

        accumulator.append("First sentence.", startingAt: 0)
        accumulator.append("Second sentence.", startingAt: 2)

        XCTAssertEqual(accumulator.text, "First sentence. Second sentence.")
    }

    func testAppendTrimsAndSkipsEmptySegments() {
        var accumulator = LivePreviewAccumulator()

        accumulator.append("  Hello.  ", startingAt: 0)
        accumulator.append("   ", startingAt: 2)
        accumulator.append("", startingAt: 4)

        XCTAssertEqual(accumulator.segments, [LiveSegment(startsAt: 0, text: "Hello.")])
    }

    func testStreamedPiecesContinueTheOpenSentence() {
        var accumulator = LivePreviewAccumulator()

        accumulator.append("so what I", startingAt: 0)
        accumulator.append("wanted to say", startingAt: 2)
        accumulator.append("is this.", startingAt: 4)

        XCTAssertEqual(accumulator.segments, [LiveSegment(startsAt: 0, text: "so what I wanted to say is this.")])
    }

    func testAFinishedSentenceStartsANewTimestampedSegment() {
        var accumulator = LivePreviewAccumulator()

        accumulator.append("Done here. And then", startingAt: 0)
        accumulator.append("more words", startingAt: 6)
        accumulator.append("Next thought", startingAt: 9)

        XCTAssertEqual(accumulator.segments, [
            LiveSegment(startsAt: 0, text: "Done here."),
            LiveSegment(startsAt: 0, text: "And then more words Next thought")
        ])
    }

    func testResetClearsSegmentsForTheNextRecording() {
        var accumulator = LivePreviewAccumulator()

        accumulator.append("Old recording.", startingAt: 0)
        accumulator.reset()

        XCTAssertEqual(accumulator.segments, [])
        XCTAssertEqual(accumulator.text, "")
    }
}
