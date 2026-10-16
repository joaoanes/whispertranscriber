import XCTest
@testable import WhisperTranscriber

final class RecencyLineTests: XCTestCase {
    func testNoSegmentsHaveNoLines() {
        XCTAssertEqual(RecencyLine.lines(in: []), [])
    }

    func testSplitsSentencesWithNewestLast() {
        let lines = RecencyLine.lines(in: [LiveSegment(startsAt: 0, text: "First one. Second one? Third one!")])

        XCTAssertEqual(lines.map(\.text), ["First one.", "Second one?", "Third one!"])
        XCTAssertEqual(lines.map(\.age), [2, 1, 0])
    }

    func testNewestLineIsLargestAndOlderLinesShrink() {
        let sizes = RecencyLine.lines(in: [LiveSegment(startsAt: 0, text: "A. B. C. D.")]).map(\.fontSize)

        XCTAssertEqual(sizes, [11, 11, 13, 17])
    }

    func testOnlyTheFirstSentenceOfASegmentCarriesItsTimestamp() {
        let lines = RecencyLine.lines(in: [
            LiveSegment(startsAt: 3, text: "Hello there. How are you?"),
            LiveSegment(startsAt: 75, text: "Fine.")
        ])

        XCTAssertEqual(lines.map(\.timestamp), ["0:03", nil, "1:15"])
    }

    func testLongRecordingsShowHours() {
        XCTAssertEqual(RecencyLine.format(3725), "1:02:05")
    }

    func testCopyingSkipsTheTimestampGutter() {
        let lines = RecencyLine.lines(in: [
            LiveSegment(startsAt: 3, text: "Hello there."),
            LiveSegment(startsAt: 75, text: "Fine.")
        ])
        let document = TranscriptDocument.build(lines)

        let copied = TranscriptDocument.copyableText(
            in: document,
            ranges: [NSRange(location: 0, length: document.length)]
        )

        XCTAssertEqual(copied, "Hello there.\nFine.")
    }
}
