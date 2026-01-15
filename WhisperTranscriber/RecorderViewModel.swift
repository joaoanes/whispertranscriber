import Foundation
import Dispatch
import AVFoundation
import WhisperKit
import AppKit

@MainActor
class RecorderViewModel: ObservableObject {
    static let shared = RecorderViewModel()

    @Published private(set) var isRecording = false
    @Published private(set) var isDownloading = false
    @Published private(set) var isPrewarming = true
    @Published private(set) var isTranscribing = false
    @Published private(set) var downloadProgress: Double = 0.0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var whisperKit: WhisperKit?
    private var lastTranscript = ""
    
    private init() {
        Task {
            await reinitWhisperKit()
        }
    }

    func reinitWhisperKit() async {
        isPrewarming = true
        whisperKit = nil
        
        let selectedModel = SettingsManager.shared.selectedModel
        
        // prevent blocking the Main Thread so we don't get reaped
        let kit = await Task.detached(priority: .userInitiated) { [weak self] () -> WhisperKit? in
             do {
                 let modelsPath = try await WhisperModelLoader.ensureModelsAreThere(selectedModel: selectedModel) { progress in
                     Task { @MainActor in
                         self?.downloadProgress = progress
                     }
                 }
                 let config = WhisperKitConfig(modelFolder: modelsPath, verbose: true, logLevel: .debug, prewarm: true, load: true, download: false)
                 let wk = try await WhisperKit(config)
                 Log.whisperKit.info("✅ Pre-warming complete")
                 return wk
             } catch {
                 Log.whisperKit.error("❌ Error during pre-warming: \(error.localizedDescription)")
                 return nil
             }
        }.value
        
        if let kit = kit {
            self.whisperKit = kit
        } else {
             errorMessage = "Error initializing WhisperKit"
        }
        
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

    private func beginRecorder() {
        let url = tempURL()
        let settings: [String: Any] = [
            AVFormatIDKey:          kAudioFormatLinearPCM,
            AVSampleRateKey:        16_000,
            AVNumberOfChannelsKey:  1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey:  false
        ]

        do {
            if SettingsManager.shared.fadeVolumeEnabled {
                let fadeDuration = Double(SettingsManager.shared.fadeMilliseconds) / 1000.0
                AudioFade.shared.fadeOut(duration: fadeDuration)
            }

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.prepareToRecord()
            if recorder?.record() == true {
                isRecording = true
                Log.recording.info("▶️ Recording started at \(url.path))")
            } else {
                Log.recording.error("❌ Recorder failed to start")
                if SettingsManager.shared.fadeVolumeEnabled {
                    let fadeDuration = Double(SettingsManager.shared.fadeMilliseconds) / 1000.0
                    AudioFade.shared.fadeIn(duration: fadeDuration)
                }
            }
        } catch {
            Log.recording.error("❌ Failed to set up recorder: \(error.localizedDescription))")
            if SettingsManager.shared.fadeVolumeEnabled {
                let fadeDuration = Double(SettingsManager.shared.fadeMilliseconds) / 1000.0
                AudioFade.shared.fadeIn(duration: fadeDuration)
            }
        }
    }

    private func stopRecording() {
        recorder?.stop()
        if recorder?.isRecording == true {
            Log.recording.error("❌ Failed to stop the recorder")
            return
        }
        isRecording = false

        if SettingsManager.shared.fadeVolumeEnabled {
            let fadeDuration = Double(SettingsManager.shared.fadeMilliseconds) / 1000.0
            AudioFade.shared.fadeIn(duration: fadeDuration)
        }

        guard let url = recorder?.url else {
            Log.recording.error("❌ No audio file URL")
            return
        }
        Log.recording.info("⏹️ Stopped. File at: \(url.path))")

        Task {
            defer { isTranscribing = false }
            isTranscribing = true
            guard let kit = whisperKit else {
                Log.whisperKit.error("❌ WhisperKit not ready")
                return
            }
            do {
                let results = try await kit.transcribe(audioPath: url.path)
                let text = results.first?.text ?? ""
                lastTranscript = text + SettingsManager.shared.suffix
                Log.whisperKit.info("📝 Transcription: \(text))")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(lastTranscript, forType: .string)

                // Add to our in-memory cache
                RecordingsManager.shared.addTranscription(for: url, text: lastTranscript)
            } catch {
                Log.whisperKit.error("❌ Transcription error: \(error.localizedDescription))")
                errorMessage = "Transcription error: \(error.localizedDescription)"
            }
        }
    }

    func retranscribe(url: URL) {
        Task {
            isTranscribing = true
            defer { isTranscribing = false }
            guard let kit = whisperKit else {
                Log.whisperKit.error("❌ WhisperKit not ready")
                return
            }
            do {
                let results = try await kit.transcribe(audioPath: url.path)
                let text = results.first?.text ?? ""
                let transcript = text + SettingsManager.shared.suffix
                Log.whisperKit.info("📝 Re-transcription: \(transcript))")

                // Add to our in-memory cache
                RecordingsManager.shared.addTranscription(for: url, text: transcript)
            } catch {
                Log.whisperKit.error("❌ Re-transcription error: \(error.localizedDescription))")
                errorMessage = "Re-transcription error: \(error.localizedDescription)"
            }
        }
    }
}
