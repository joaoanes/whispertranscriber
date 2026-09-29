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

    func testLiveTranscriptionCanBeToggled() {
        let original = settingsManager.liveTranscriptionEnabled
        defer { settingsManager.liveTranscriptionEnabled = original }

        settingsManager.liveTranscriptionEnabled = false
        XCTAssertFalse(settingsManager.liveTranscriptionEnabled)

        settingsManager.liveTranscriptionEnabled = true
        XCTAssertTrue(settingsManager.liveTranscriptionEnabled)
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

    func testCleanupOptionsFollowTheCleanupToggle() {
        let original = settingsManager.cleanupEnabled
        defer { settingsManager.cleanupEnabled = original }

        settingsManager.cleanupEnabled = false

        XCTAssertFalse(settingsManager.cleanupOptions.enabled)

        settingsManager.cleanupEnabled = true

        XCTAssertTrue(settingsManager.cleanupOptions.enabled)
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
