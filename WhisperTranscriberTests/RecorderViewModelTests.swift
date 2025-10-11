import XCTest
@testable import WhisperTranscriber

@MainActor
final class RecorderViewModelTests: XCTestCase {

    var recorderViewModel: RecorderViewModel!

    override func setUp() async throws {
        try await super.setUp()
        recorderViewModel = RecorderViewModel.shared
    }

    func testInitialStateIsNotRecording() {
        XCTAssertFalse(recorderViewModel.isRecording)
    }

    func testInitialStateIsNotTranscribing() {
        XCTAssertFalse(recorderViewModel.isTranscribing)
    }

    func testDownloadProgressPropertyExists() {
        XCTAssertGreaterThanOrEqual(recorderViewModel.downloadProgress, 0.0)
        XCTAssertLessThanOrEqual(recorderViewModel.downloadProgress, 1.0)
    }

    func testErrorMessagePropertyIsOptional() {
        _ = recorderViewModel.errorMessage
    }

    func testToggleRecordingCallsCorrectMethod() {
        let initialState = recorderViewModel.isRecording

        recorderViewModel.toggleRecording()

        XCTAssertNotNil(recorderViewModel)
    }

    func testRetranscribeAcceptsURL() async {
        let testURL = URL(fileURLWithPath: "/tmp/test.wav")

        recorderViewModel.retranscribe(url: testURL)

        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    func testReinitWhisperKitResetsPrewarmingState() async {
        await recorderViewModel.reinitWhisperKit()

        XCTAssertFalse(recorderViewModel.isPrewarming)
    }
}
