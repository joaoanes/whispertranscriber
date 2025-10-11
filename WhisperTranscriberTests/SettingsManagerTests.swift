import XCTest
@testable import WhisperTranscriber

@MainActor
final class SettingsManagerTests: XCTestCase {

    var settingsManager: SettingsManager!

    override func setUp() async throws {
        try await super.setUp()
        settingsManager = SettingsManager.shared
    }

    func testHotkeyPropertyExists() {
        XCTAssertNotNil(settingsManager.hotkey)
    }

    func testSuffixPropertyExists() {
        XCTAssertNotNil(settingsManager.suffix)
    }

    func testModelPropertyExists() {
        XCTAssertFalse(settingsManager.selectedModel.isEmpty)
    }

    func testFadeMillisecondsPropertyExists() {
        XCTAssertGreaterThanOrEqual(settingsManager.fadeMilliseconds, 0)
    }

    func testHotkeyCanBeUpdated() {
        settingsManager.hotkey = "⌘R"

        XCTAssertEqual(settingsManager.hotkey, "⌘R")
    }

    func testSuffixCanBeUpdated() {
        settingsManager.suffix = "\n\n---\n"

        XCTAssertEqual(settingsManager.suffix, "\n\n---\n")
    }

    func testModelCanBeUpdated() {
        settingsManager.selectedModel = "openai_whisper-small"

        XCTAssertEqual(settingsManager.selectedModel, "openai_whisper-small")
    }

    func testFadeMillisecondsCanBeUpdated() {
        settingsManager.fadeMilliseconds = 1000

        XCTAssertEqual(settingsManager.fadeMilliseconds, 1000)
    }

    func testFadeMillisecondsAcceptsZero() {
        settingsManager.fadeMilliseconds = 0

        XCTAssertEqual(settingsManager.fadeMilliseconds, 0)
    }
}
