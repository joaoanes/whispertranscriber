import XCTest
@testable import WhisperTranscriber

class UtilsPathTests: XCTestCase {
    func testTempURLUsesApplicationSupport() {
        let url = tempURL()
        XCTAssertTrue(url.path.contains("Application Support"), "Path should contain Application Support")
        XCTAssertTrue(url.path.contains("WhisperTranscriber"), "Path should contain WhisperTranscriber")
        XCTAssertTrue(url.path.contains("Recordings"), "Path should contain Recordings")
        XCTAssertEqual(url.pathExtension, "wav")
    }

    func testGetRecordingsDirectoryCreatesDirectory() {
        let dir = getRecordingsDirectory()
        XCTAssertNotNil(dir)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir!.path, isDirectory: &isDir)
        XCTAssertTrue(exists)
        XCTAssertTrue(isDir.boolValue)
    }
}
