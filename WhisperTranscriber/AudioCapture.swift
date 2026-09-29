import AVFoundation
import FluidAudio
import Foundation

final class AudioCapture: @unchecked Sendable {
    static let sampleRate = 16_000.0

    private let engine = AVAudioEngine()
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

        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 4096, format: input.outputFormat(forBus: 0)) {
            [weak self] buffer, _ in
            self?.handle(buffer)
        }
        engine.prepare()
        try engine.start()

        return stream
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
        continuation?.finish()
        continuation = nil
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
