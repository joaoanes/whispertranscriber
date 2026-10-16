import AVFoundation
import FluidAudio
import Foundation

enum AudioCaptureError: LocalizedError {
    case noInputDevice

    var errorDescription: String? {
        "No usable microphone input is available"
    }
}

final class AudioCapture: @unchecked Sendable {
    static let sampleRate = 16_000.0

    private var engine: AVAudioEngine?
    private var configurationObserver: NSObjectProtocol?
    private let converter = AudioConverter()
    private let lock = NSLock()
    private let processingFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: AudioCapture.sampleRate,
        channels: 1,
        interleaved: false
    )!

    private var file: AVAudioFile?
    private var captured: [Float] = []
    private var continuation: AsyncStream<[Float]>.Continuation?

    var samples: [Float] {
        lock.withLock { captured }
    }

    static func loadSamples(from url: URL) throws -> [Float] {
        try AudioConverter().resampleAudioFile(url)
    }

    func start(writingTo url: URL, emittingChunks: Bool) throws -> AsyncStream<[Float]>? {
        lock.withLock { captured = [] }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: AudioCapture.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]
        file = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        let stream: AsyncStream<[Float]>? = emittingChunks
            ? AsyncStream { continuation in self.continuation = continuation }
            : nil

        do {
            try launchEngine()
        } catch {
            file = nil
            continuation?.finish()
            continuation = nil
            throw error
        }

        return stream
    }

    func stop() {
        tearDownEngine()
        file = nil
        continuation?.finish()
        continuation = nil
    }

    private func launchEngine() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioCaptureError.noInputDevice
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.handle(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }

        self.engine = engine
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.relaunchAfterConfigurationChange()
        }
        Log.recording.info("🎙️ Capturing at \(format.sampleRate)) Hz, \(format.channelCount)) ch")
    }

    private func tearDownEngine() {
        configurationObserver.map(NotificationCenter.default.removeObserver)
        configurationObserver = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }

    private func relaunchAfterConfigurationChange() {
        guard engine != nil else { return }
        Log.recording.info("🔁 Audio device configuration changed, restarting capture")
        tearDownEngine()
        do {
            try launchEngine()
        } catch {
            Log.recording.error("❌ Failed to restart capture: \(error.localizedDescription))")
        }
    }

    private func handle(_ buffer: AVAudioPCMBuffer) {
        do {
            let chunk = try converter.resampleBuffer(buffer)
            guard !chunk.isEmpty else { return }
            try write(chunk)
            lock.withLock { captured.append(contentsOf: chunk) }
            continuation?.yield(chunk)
        } catch {
            Log.recording.error("❌ Failed to process captured audio: \(error.localizedDescription)")
        }
    }

    private func write(_ chunk: [Float]) throws {
        guard let file,
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: processingFormat,
                  frameCapacity: AVAudioFrameCount(chunk.count)
              ),
              let channel = buffer.floatChannelData
        else { return }

        buffer.frameLength = AVAudioFrameCount(chunk.count)
        chunk.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel[0].update(from: base, count: chunk.count)
        }
        try file.write(from: buffer)
    }
}
