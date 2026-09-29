import AppKit
import AVFoundation
import Dispatch
import Foundation

@MainActor
class RecorderViewModel: ObservableObject {
    static let shared = RecorderViewModel()

    @Published private(set) var isRecording = false
    @Published private(set) var isDownloading = false
    @Published private(set) var isPrewarming = true
    @Published private(set) var isTranscribing = false
    @Published private(set) var downloadProgress: Double = 0.0
    @Published private(set) var livePreview = ""
    @Published var errorMessage: String?

    private let engine: SpeechTranscribing
    private let capture: AudioCapturing
    private var recordingURL: URL?
    private var previewTask: Task<Void, Never>?
    private var lastTranscript = ""
    private(set) var finalizeTask: Task<Void, Never>?

    init(
        engine: SpeechTranscribing = ParakeetEngine(),
        capture: AudioCapturing = AudioCapture(),
        prewarm: Bool = true
    ) {
        self.engine = engine
        self.capture = capture
        guard prewarm else {
            isPrewarming = false
            return
        }
        Task {
            await reloadEngine()
        }
    }

    func reloadEngine() async {
        isPrewarming = true
        await engine.unload()

        do {
            try await engine.prepare { [weak self] progress in
                Task { @MainActor in
                    self?.isDownloading = progress < 1.0
                    self?.downloadProgress = progress
                }
            }
            Log.speech.info("✅ Pre-warming complete")
        } catch {
            Log.speech.error("❌ Error during pre-warming: \(error.localizedDescription)")
            errorMessage = "Error initializing the speech engine: \(error.localizedDescription)"
        }

        isDownloading = false
        isPrewarming = false
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            requestAndStart()
        }
    }

    private func requestAndStart() {
        requestMicPermission { [weak self] granted in
            guard granted, let self = self else { return }
            DispatchQueue.main.async {
                self.beginRecorder()
            }
        }
    }

    func beginRecorder() {
        let url = tempURL()

        let live = SettingsManager.shared.liveTranscriptionEnabled

        do {
            fadeOutIfEnabled()
            let chunks = try capture.start(writingTo: url, emittingChunks: live)
            recordingURL = url
            isRecording = true
            livePreview = ""
            if let chunks {
                previewTask = Task { [weak self] in
                    await self?.followLivePreview(chunks, for: url)
                }
            }
            Log.recording.info("▶️ Recording started at \(url.path)) (live transcription: \(live))")
        } catch {
            Log.recording.error("❌ Failed to set up recorder: \(error.localizedDescription))")
            errorMessage = "Could not start recording: \(error.localizedDescription)"
            fadeInIfEnabled()
        }
    }

    private func followLivePreview(_ chunks: AsyncStream<[Float]>, for url: URL) async {
        await engine.resetSpeechBoundaries()
        var accumulator = LivePreviewAccumulator()

        for await chunk in chunks {
            guard let boundary = try? await engine.speechEndIndex(in: chunk) else { continue }

            let captured = capture.samples
            guard let segment = accumulator.claimSegment(
                upTo: boundary,
                capturedCount: captured.count
            ) else { continue }

            guard let text = try? await engine.transcribe(Array(captured[segment])), !text.isEmpty
            else { continue }

            accumulator.append(text)
            livePreview = accumulator.text
            Log.speech.info("📝 Live segment: \(text)")
            RecordingsManager.shared.addTranscription(for: url, text: livePreview)
        }
    }

    func stopRecording() {
        capture.stop()
        isRecording = false
        fadeInIfEnabled()

        guard let url = recordingURL else {
            Log.recording.error("❌ No audio file URL")
            return
        }
        Log.recording.info("⏹️ Stopped. File at: \(url.path))")

        let captured = capture.samples
        let draining = previewTask
        previewTask = nil

        finalizeTask = Task {
            await draining?.value
            defer { isTranscribing = false }
            isTranscribing = true
            await transcribeAndPublish(captured, for: url)
        }
    }

    private func finalTranscript(for samples: [Float]) async throws -> String? {
        let speech = try await engine.speechOnly(samples)
        guard !speech.isEmpty else { return nil }

        let text = SettingsManager.shared.speakerDetectionEnabled
            ? try await engine.transcribeWithSpeakers(speech)
            : try await engine.transcribe(speech)
        let cleaned = TextCleanup.apply(to: text, options: SettingsManager.shared.cleanupOptions)
        return cleaned + SettingsManager.shared.suffix
    }

    private func transcribeAndPublish(_ samples: [Float], for url: URL) async {
        do {
            guard let transcript = try await finalTranscript(for: samples) else {
                Log.speech.info("🔇 No speech detected, skipping transcription")
                livePreview = ""
                return
            }

            lastTranscript = transcript
            Log.speech.info("📝 Transcription: \(transcript))")

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(transcript, forType: .string)
            RecordingsManager.shared.addTranscription(for: url, text: transcript)
            livePreview = ""
        } catch {
            Log.speech.error("❌ Transcription error: \(error.localizedDescription))")
            errorMessage = "Transcription error: \(error.localizedDescription)"
        }
    }

    func retranscribe(url: URL) {
        finalizeTask = Task {
            isTranscribing = true
            defer { isTranscribing = false }
            do {
                let samples = try AudioCapture.loadSamples(from: url)
                guard let transcript = try await finalTranscript(for: samples) else {
                    Log.speech.info("🔇 No speech detected in \(url.lastPathComponent)")
                    return
                }
                Log.speech.info("📝 Re-transcription: \(transcript))")

                RecordingsManager.shared.addTranscription(for: url, text: transcript)
            } catch {
                Log.speech.error("❌ Re-transcription error: \(error.localizedDescription))")
                errorMessage = "Re-transcription error: \(error.localizedDescription)"
            }
        }
    }

    private func fadeOutIfEnabled() {
        guard SettingsManager.shared.fadeVolumeEnabled else { return }
        AudioFade.shared.fadeOut(duration: Double(SettingsManager.shared.fadeMilliseconds) / 1000.0)
    }

    private func fadeInIfEnabled() {
        guard SettingsManager.shared.fadeVolumeEnabled else { return }
        AudioFade.shared.fadeIn(duration: Double(SettingsManager.shared.fadeMilliseconds) / 1000.0)
    }
}
