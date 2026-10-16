import AVFoundation
import FluidAudio
import Foundation

enum AudioCaptureError: LocalizedError {
    case noInputDevice
    case cannotSelectInputDevice(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            "No usable microphone input is available"
        case .cannotSelectInputDevice(let status):
            "Could not switch to the selected microphone (\(status))"
        }
    }
}

final class AudioCapture: @unchecked Sendable {
    static let sampleRate = 16_000.0

    private var engine: AVAudioEngine?
    private var tapFormat: AVAudioFormat?
    private var inputDevice: AudioDeviceID?
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

    func start(
        writingTo url: URL,
        emittingChunks: Bool,
        inputDevice: AudioDeviceID?
    ) throws -> AsyncStream<[Float]>? {
        lock.withLock { captured = [] }
        self.inputDevice = inputDevice ?? AudioInputDevices.systemDefaultID()

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
        try inputDevice.map { try select($0, on: input) }
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
        tapFormat = format
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.relaunchAfterConfigurationChange()
        }
        Log.recording.info("🎙️ Capturing at \(format.sampleRate)) Hz, \(format.channelCount)) ch")
    }

    private func select(_ device: AudioDeviceID, on input: AVAudioInputNode) throws {
        guard let unit = input.audioUnit else { throw AudioCaptureError.noInputDevice }
        var device = device
        let status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw AudioCaptureError.cannotSelectInputDevice(status) }
    }

    private func tearDownEngine() {
        configurationObserver.map(NotificationCenter.default.removeObserver)
        configurationObserver = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        tapFormat = nil
    }

    private func relaunchAfterConfigurationChange() {
        guard let engine, !engine.isRunning, let tapFormat else { return }
        let hardwareFormat = engine.inputNode.inputFormat(forBus: 0)
        let formatUnchanged = hardwareFormat.sampleRate == tapFormat.sampleRate
            && hardwareFormat.channelCount == tapFormat.channelCount

        if formatUnchanged {
            Log.recording.info("🔁 Audio engine stopped by a configuration change, resuming")
            do {
                try engine.start()
                return
            } catch {
                Log.recording.error("❌ Failed to resume capture: \(error.localizedDescription))")
            }
        }

        Log.recording.info("🔁 Input format changed to \(hardwareFormat.sampleRate)) Hz, rebuilding capture")
        tearDownEngine()
        do {
            try launchEngine()
        } catch {
            Log.recording.error("❌ Microphone unusable, falling back to system default: \(error.localizedDescription))")
            fallBackToSystemDefault()
        }
    }

    private func fallBackToSystemDefault() {
        inputDevice = AudioInputDevices.systemDefaultID()
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
