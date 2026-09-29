import XCTest
@testable import WhisperTranscriber

final class LivePreviewAccumulatorTests: XCTestCase {

    func testFirstSegmentStartsAtZero() {
        var accumulator = LivePreviewAccumulator()

        XCTAssertEqual(accumulator.claimSegment(upTo: 16_000, capturedCount: 20_000), 0..<16_000)
    }

    func testSecondSegmentStartsWhereTheFirstEnded() {
        var accumulator = LivePreviewAccumulator()

        _ = accumulator.claimSegment(upTo: 16_000, capturedCount: 20_000)

        XCTAssertEqual(
            accumulator.claimSegment(upTo: 40_000, capturedCount: 48_000),
            16_000..<40_000
        )
    }

    func testNeverReplaysAlreadyCommittedAudio() {
        var accumulator = LivePreviewAccumulator()
        var covered: [Int] = []

        for boundary in [10_000, 25_000, 60_000] {
            guard let segment = accumulator.claimSegment(upTo: boundary, capturedCount: 80_000)
            else { continue }
            covered.append(contentsOf: segment)
        }

        XCTAssertEqual(covered.count, Set(covered).count)
        XCTAssertEqual(covered.count, 60_000)
    }

    func testIgnoresBoundaryThatDoesNotAdvance() {
        var accumulator = LivePreviewAccumulator()

        _ = accumulator.claimSegment(upTo: 16_000, capturedCount: 20_000)

        XCTAssertNil(accumulator.claimSegment(upTo: 16_000, capturedCount: 20_000))
        XCTAssertNil(accumulator.claimSegment(upTo: 8_000, capturedCount: 20_000))
        XCTAssertEqual(accumulator.committed, 16_000)
    }

    func testIgnoresBoundaryBeyondCapturedAudio() {
        var accumulator = LivePreviewAccumulator()

        XCTAssertNil(accumulator.claimSegment(upTo: 30_000, capturedCount: 20_000))
        XCTAssertEqual(accumulator.committed, 0)
    }

    func testAppendJoinsSegmentsWithASingleSpace() {
        var accumulator = LivePreviewAccumulator()

        accumulator.append("First sentence.")
        accumulator.append("Second sentence.")

        XCTAssertEqual(accumulator.text, "First sentence. Second sentence.")
    }

    func testAppendTrimsAndSkipsEmptySegments() {
        var accumulator = LivePreviewAccumulator()

        accumulator.append("  Hello.  ")
        accumulator.append("   ")
        accumulator.append("")

        XCTAssertEqual(accumulator.text, "Hello.")
    }

    func testResetClearsProgressForTheNextRecording() {
        var accumulator = LivePreviewAccumulator()

        _ = accumulator.claimSegment(upTo: 16_000, capturedCount: 20_000)
        accumulator.append("Old recording.")

        accumulator.reset()

        XCTAssertEqual(accumulator.committed, 0)
        XCTAssertEqual(accumulator.text, "")
        XCTAssertEqual(accumulator.claimSegment(upTo: 5_000, capturedCount: 8_000), 0..<5_000)
    }
}
