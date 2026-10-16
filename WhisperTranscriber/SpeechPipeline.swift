import CoreAudio
import Foundation

protocol SpeechTranscribing: Sendable {
    func prepare(progressCallback: @escaping @Sendable (Double) -> Void) async throws
    func unload() async
    func transcribe(_ samples: [Float]) async throws -> String
    func transcribeWithSpeakers(_ samples: [Float]) async throws -> String
    func speechOnly(_ samples: [Float]) async throws -> [Float]
    func startLiveTranscription() async throws -> AsyncStream<LiveTranscriptChunk>
    func feedLive(_ samples: [Float]) async
    func finishLiveTranscription() async
}

protocol AudioCapturing: AnyObject {
    var samples: [Float] { get }
    func start(writingTo url: URL, emittingChunks: Bool, inputDevice: AudioDeviceID?) throws -> AsyncStream<[Float]>?
    func stop()
}

extension ParakeetEngine: SpeechTranscribing {}

extension AudioCapture: AudioCapturing {}
