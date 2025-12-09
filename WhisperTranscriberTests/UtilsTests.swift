import XCTest
import AVFoundation
@testable import WhisperTranscriber

final class UtilsTests: XCTestCase {

    func testTempURLHasCachesDirectory() {
        let url = tempURL()

        XCTAssertTrue(url.path.contains("Application Support"))
    }

    func testTempURLHasWavExtension() {
        let url = tempURL()

        XCTAssertEqual(url.pathExtension, "wav")
    }

    func testTempURLHasRecordingPrefix() {
        let url = tempURL()

        XCTAssertTrue(url.lastPathComponent.hasPrefix("recording_"))
    }

    func testTempURLIncludesTimestamp() {
        let url = tempURL()
        let filename = url.lastPathComponent

        let timestampString = filename
            .replacingOccurrences(of: "recording_", with: "")
            .replacingOccurrences(of: ".wav", with: "")

        XCTAssertNotNil(Int(timestampString))
    }

    func testTempURLGeneratesUniqueURLs() {
        let url1 = tempURL()
        Thread.sleep(forTimeInterval: 1.1)
        let url2 = tempURL()

        XCTAssertNotEqual(url1, url2)
    }

    func testUTGetOSTypeFromStringConverts4CharString() {
        let result = UTGetOSTypeFromString("SwHK")

        XCTAssertNotEqual(result, 0)
    }

    func testUTGetOSTypeFromStringProducesSameResultForSameInput() {
        let result1 = UTGetOSTypeFromString("TEST")
        let result2 = UTGetOSTypeFromString("TEST")

        XCTAssertEqual(result1, result2)
    }

    func testUTGetOSTypeFromStringProducesDifferentResultsForDifferentInputs() {
        let result1 = UTGetOSTypeFromString("AAA1")
        let result2 = UTGetOSTypeFromString("AAA2")

        XCTAssertNotEqual(result1, result2)
    }

    func testRequestMicPermissionCallsCallbackWhenAuthorized() {
        let originalAuthStatus = getAudioAuthStatus
        let originalAudioAccess = requestAudioAccess
        defer {
            getAudioAuthStatus = originalAuthStatus
            requestAudioAccess = originalAudioAccess
        }

        getAudioAuthStatus = { .authorized }
        requestAudioAccess = { cb in cb(true) }

        let expectation = expectation(description: "Mic permission callback")
        var grantedResult: Bool?

        requestMicPermission { granted in
            grantedResult = granted
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(grantedResult == true)
    }

    func testRequestMicPermissionCallsCallbackWhenDenied() {
        let originalAuthStatus = getAudioAuthStatus
        let originalAudioAccess = requestAudioAccess
        defer {
            getAudioAuthStatus = originalAuthStatus
            requestAudioAccess = originalAudioAccess
        }

        getAudioAuthStatus = { .denied }
        requestAudioAccess = { cb in cb(false) }

        let expectation = expectation(description: "Mic permission callback")
        var grantedResult: Bool?

        requestMicPermission { granted in
            grantedResult = granted
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertFalse(grantedResult == true)
    }

    func testRequestMicPermissionRequestsAccessWhenNotDetermined() {
        let originalAuthStatus = getAudioAuthStatus
        let originalAudioAccess = requestAudioAccess
        defer {
            getAudioAuthStatus = originalAuthStatus
            requestAudioAccess = originalAudioAccess
        }

        getAudioAuthStatus = { .notDetermined }
        var requestAccessCalled = false
        requestAudioAccess = { cb in
            requestAccessCalled = true
            cb(true)
        }

        let expectation = expectation(description: "Mic permission callback")

        requestMicPermission { granted in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(requestAccessCalled)
    }
}
