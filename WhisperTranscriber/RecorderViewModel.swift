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
            let config = WhisperKitConfig(modelFolder: modelsPath, logLevel: .debug, prewarm: true, load: true, download: false)
            whisperKit = try await WhisperKit(config)

            isPrewarming = false
            print("✅ Pre-warming complete")
        } catch {
            print("❌ Error during pre-warming:", error)
            errorMessage = "Error during pre-warming: \(error.localizedDescription)"
        }
    }
    
    private func ensureModelsAreThere() async throws -> String {
        #if LITE_MODE
        return try await setupLiteModels()
        #else
        guard let basePath = Bundle.main.resourceURL?.appendingPathComponent("hf/models/argmaxinc/whisperkit-coreml/\(SettingsManager.shared.selectedModel)") else {
            throw NSError(domain: "AppError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find models path in bundle."])
        }
        return basePath.path
        #endif
    }

    private func setupLiteModels() async throws -> String {
        let fm = FileManager.default
        let cacheURL = try getCacheDirectory()
        let modelPathURL = cacheURL.appendingPathComponent("hf/models/argmaxinc/whisperkit-coreml/\(SettingsManager.shared.selectedModel)")
        let tokenizerPathURL = cacheURL.appendingPathComponent("hf/")
        
        let components = SettingsManager.shared.selectedModel.components(separatedBy: "_")
        let modelName = components.count > 1 ? components[1].replacingOccurrences(of: "whisper-", with: "") : "large-v3"

        let configPath = tokenizerPathURL.appendingPathComponent("models/openai/whisper-\(modelName)/config.json").path
        if fm.fileExists(atPath: configPath) {
            print("✅ Models already exist at", modelPathURL.path)
            return modelPathURL.path
        }
        
        isDownloading = true
        defer { isDownloading = false }
        
        print("⬇️ Downloading models...")
        try await downloadAndInstallModels(to: modelPathURL, tokenizerPath: tokenizerPathURL, fileManager: fm)
        
        return modelPathURL.path
    }

    private func getCacheDirectory() throws -> URL {
        let fm = FileManager.default
        guard let cacheURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "AppError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not get cache directory."])
        }
        let appCacheURL = cacheURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.joaoanes.WhisperTranscriberLite")
        try fm.createDirectory(at: appCacheURL, withIntermediateDirectories: true, attributes: nil)
        return appCacheURL
    }

    private func downloadAndInstallModels(to modelURL: URL, tokenizerPath: URL, fileManager fm: FileManager) async throws {
        // Download model
        let downloadedModelURL = try await WhisperKit.download(variant: SettingsManager.shared.selectedModel) { progress in
            DispatchQueue.main.async {
                self.downloadProgress = progress.fractionCompleted
            }
        }
        
        let components = SettingsManager.shared.selectedModel.components(separatedBy: "_")
        let modelName = components.count > 1 ? components[1].replacingOccurrences(of: "whisper-", with: "") : "large-v3"
        let tokenizerVariant = WhisperKit.tokenizerVariant(for: modelName)

        // Download tokenizer
        _ = try await loadTokenizer(for: tokenizerVariant, tokenizerFolder: tokenizerPath, useBackgroundSession: false)
        
        // Move model to cache
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
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.prepareToRecord()
            if recorder?.record() == true {
                isRecording = true
                print("▶️ Recording started at", url.path)
            } else {
                print("❌ Recorder failed to start")
            }
        } catch {
            print("❌ Failed to set up recorder:", error)
        }
    }

    private func stopRecording() {
        recorder?.stop()
        if recorder?.isRecording == true {
            print("❌ Failed to stop the recorder")
            return
        }
        isRecording = false

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
            } catch {
                print("❌ Transcription error:", error)
                errorMessage = "Transcription error: \(error.localizedDescription)"
            }
        }
    }

}
