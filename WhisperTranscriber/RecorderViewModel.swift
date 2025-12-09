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
        do {
            let modelsPath = try await ensureModelsAreThere()
            let config = WhisperKitConfig(modelFolder: modelsPath, verbose: true, logLevel: .debug, prewarm: true, load: true, download: false)
            whisperKit = try await WhisperKit(config)

            isPrewarming = false
            print("✅ Pre-warming complete")
        } catch {
            print("❌ Error during pre-warming:", error)
            errorMessage = "Error during pre-warming: \(error.localizedDescription)"
            isPrewarming = false
        }
    }
    
    private func ensureModelsAreThere() async throws -> String {
        let selectedModel = SettingsManager.shared.selectedModel
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("hf/models/argmaxinc/whisperkit-coreml/\(selectedModel)") {
             if FileManager.default.fileExists(atPath: bundlePath.path) {
                 print("✅ Found models in app bundle at", bundlePath.path)
                 return bundlePath.path
             }
        }
        return try await setupLiteModels()
    }

    private func setupLiteModels() async throws -> String {
        let fm = FileManager.default
        let modelsURL = try getModelsDirectoryInternal()

        let selectedModel = SettingsManager.shared.selectedModel
        let modelPathURL = modelsURL.appendingPathComponent("hf/models/argmaxinc/whisperkit-coreml/\(selectedModel)")
        let tokenizerPathURL = modelsURL.appendingPathComponent("hf/")

        // Check for models in old cache directory and migrate if possible
        migrateOldModels(to: modelPathURL, fileManager: fm)
        
        if fm.fileExists(atPath: modelPathURL.path) {
            print("✅ Models already exist at", modelPathURL.path)
            return modelPathURL.path
        }
        
        isDownloading = true
        defer { isDownloading = false }
        
        print("⬇️ Downloading models...")
        try await downloadAndInstallModels(to: modelPathURL, tokenizerPath: tokenizerPathURL, fileManager: fm)
        
        return modelPathURL.path
    }

    private func getModelsDirectoryInternal() throws -> URL {
        guard let modelsDir = getModelsDirectory() else {
            throw NSError(domain: "AppError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not get models directory."])
        }
        return modelsDir
    }

    private func migrateOldModels(to newModelURL: URL, fileManager fm: FileManager) {
        guard let cacheURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let oldAppCacheURL = cacheURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.joaoanes.WhisperTranscriberLite")

        let selectedModel = SettingsManager.shared.selectedModel
        let oldModelPathURL = oldAppCacheURL.appendingPathComponent("hf/models/argmaxinc/whisperkit-coreml/\(selectedModel)")

        if fm.fileExists(atPath: oldModelPathURL.path) && !fm.fileExists(atPath: newModelURL.path) {
            print("📦 Migrating models from Cache to Application Support...")
            do {
                try fm.createDirectory(at: newModelURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                try fm.moveItem(at: oldModelPathURL, to: newModelURL)
                print("✅ Migration successful.")
            } catch {
                print("❌ Migration failed: \(error)")
            }
        }
    }

    private func getTokenizerVariant(for model: String) -> ModelVariant {
        if model.contains("large-v3") {
            return .largev3
        } else if model.contains("large-v2") {
            return .largev2
        } else if model.contains("medium") {
            return .medium
        } else if model.contains("small") {
            return .small
        } else if model.contains("base") {
            return .base
        } else if model.contains("tiny") {
            return .tiny
        } else if model.contains("distil-large-v3") {
            return .largev3
        } else {
            return .largev3
        }
    }

    private func downloadAndInstallModels(to modelURL: URL, tokenizerPath: URL, fileManager fm: FileManager) async throws {
        // Download model
        let downloadedModelURL = try await WhisperKit.download(variant: SettingsManager.shared.selectedModel) { progress in
            DispatchQueue.main.async {
                self.downloadProgress = progress.fractionCompleted
            }
        }
        
        let tokenizerVariant = getTokenizerVariant(for: SettingsManager.shared.selectedModel)

        // Download tokenizer
        _ = try await ModelUtilities.loadTokenizer(for: tokenizerVariant)
        
        // Move model to destination
        if fm.fileExists(atPath: modelURL.path) {
            try fm.removeItem(at: modelURL)
        }
        try fm.createDirectory(at: modelURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: downloadedModelURL, to: modelURL)
        print("✅ Models downloaded and installed.")
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
                print("▶️ Recording started at", url.path)
            } else {
                print("❌ Recorder failed to start")
                if SettingsManager.shared.fadeVolumeEnabled {
                    let fadeDuration = Double(SettingsManager.shared.fadeMilliseconds) / 1000.0
                    AudioFade.shared.fadeIn(duration: fadeDuration)
                }
            }
        } catch {
            print("❌ Failed to set up recorder:", error)
            if SettingsManager.shared.fadeVolumeEnabled {
                let fadeDuration = Double(SettingsManager.shared.fadeMilliseconds) / 1000.0
                AudioFade.shared.fadeIn(duration: fadeDuration)
            }
        }
    }

    private func stopRecording() {
        recorder?.stop()
        if recorder?.isRecording == true {
            print("❌ Failed to stop the recorder")
            return
        }
        isRecording = false

        if SettingsManager.shared.fadeVolumeEnabled {
            let fadeDuration = Double(SettingsManager.shared.fadeMilliseconds) / 1000.0
            AudioFade.shared.fadeIn(duration: fadeDuration)
        }

        guard let url = recorder?.url else {
            print("❌ No audio file URL")
            return
        }
        print("⏹️ Stopped. File at:", url.path)

        Task {
            defer { isTranscribing = false }
            isTranscribing = true
            guard let kit = whisperKit else {
                print("❌ WhisperKit not ready")
                return
            }
            do {
                let results = try await kit.transcribe(audioPath: url.path)
                let text = results.first?.text ?? ""
                lastTranscript = text + SettingsManager.shared.suffix
                print("📝 Transcription:", text)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(lastTranscript, forType: .string)

                // Add to our in-memory cache
                RecordingsManager.shared.addTranscription(for: url, text: lastTranscript)
            } catch {
                print("❌ Transcription error:", error)
                errorMessage = "Transcription error: \(error.localizedDescription)"
            }
        }
    }

    func retranscribe(url: URL) {
        Task {
            isTranscribing = true
            defer { isTranscribing = false }
            guard let kit = whisperKit else {
                print("❌ WhisperKit not ready")
                return
            }
            do {
                let results = try await kit.transcribe(audioPath: url.path)
                let text = results.first?.text ?? ""
                let transcript = text + SettingsManager.shared.suffix
                print("📝 Re-transcription:", transcript)

                // Add to our in-memory cache
                RecordingsManager.shared.addTranscription(for: url, text: transcript)
            } catch {
                print("❌ Re-transcription error:", error)
                errorMessage = "Re-transcription error: \(error.localizedDescription)"
            }
        }
    }
}
