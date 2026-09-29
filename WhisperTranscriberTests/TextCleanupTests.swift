import XCTest
@testable import WhisperTranscriber

final class TextCleanupTests: XCTestCase {

    private func options(enabled: Bool = true, removeUm: Bool = false) -> TextCleanupOptions {
        TextCleanupOptions(enabled: enabled, removeUm: removeUm)
    }

    func testRemovesFillerWords() {
        let result = TextCleanup.apply(to: "so uh this is uhh a test", options: options())

        XCTAssertEqual(result, "So this is a test")
    }

    func testKeepsUmByDefault() {
        let result = TextCleanup.apply(to: "um dia bonito", options: options())

        XCTAssertEqual(result, "Um dia bonito")
    }

    func testRemovesUmWhenEnabled() {
        let result = TextCleanup.apply(to: "so um yeah", options: options(removeUm: true))

        XCTAssertEqual(result, "So yeah")
    }

    func testTidiesWhitespaceAndPunctuation() {
        let result = TextCleanup.apply(to: "  hello   there , world .  ", options: options())

        XCTAssertEqual(result, "Hello there, world.")
    }

    func testDisabledOptionsLeaveTextCompletelyUntouched() {
        let result = TextCleanup.apply(to: "uh keep um this", options: .disabled)

        XCTAssertEqual(result, "uh keep um this")
    }

    func testDisabledOptionsDoNotEvenTidyWhitespace() {
        let result = TextCleanup.apply(to: "  spaced   out , text .  ", options: .disabled)

        XCTAssertEqual(result, "  spaced   out , text .  ")
    }
}
