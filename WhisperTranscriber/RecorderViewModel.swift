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

    private var recorder: AVAudioRecorder?
    private var whisperKit: WhisperKit?
    private var lastTranscript = ""
    
    private init() {
        Task {
            do {
                let modelsPath = try await ensureModelsAreThere()
                let config = WhisperKitConfig(modelFolder: modelsPath, logLevel: .debug, prewarm: true, load: true, download: false)
                whisperKit = try await WhisperKit(config)

                isPrewarming = false
                print("✅ Pre-warming complete")
            } catch {
                print("❌ Error during pre-warming:", error)
            }
        }
    }
    
    private func ensureModelsAreThere() async throws -> String  {
        #if LITE_MODE
            let cachesURL = FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.joaoanes.WhisperTranscriberLite")
        
            
            let path = cachesURL
                .appendingPathComponent("hf/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930")
                .path
            let tokenizerPath = cachesURL
                .appendingPathComponent("hf/")
                
            let configPath = tokenizerPath.path() + "/models/openai/whisper-large-v3/config.json"
            if FileManager.default.fileExists(atPath: configPath) {
                print("models exist at", configPath)
                return path
            }
            
            isDownloading = true
            
            let fm = FileManager.default
            try fm.createDirectory(at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true)
            print("downloading")
        
            let downloadedModelPath = try await WhisperKit.download(variant: "openai_whisper-large-v3-v20240930") { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress.fractionCompleted
                }
            }
        
            print("tokenizer")
        
            _ = try await loadTokenizer(for: ModelVariant.largev3, tokenizerFolder: tokenizerPath, useBackgroundSession: false)
        
            print("downloaded")
            let downloadedURL = downloadedModelPath
            
            let targetURL = URL(fileURLWithPath: path)
            if fm.fileExists(atPath: targetURL.path) {
                try fm.removeItem(at: targetURL)
            }
            try fm.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: downloadedURL, to: targetURL)
        
            isDownloading = false
        
            return path
        #else
            let basePath = Bundle.main.resourceURL!.path + "/hf"
            let modelsPath = basePath + "/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930"
        
            return modelsPath
        #endif
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
                lastTranscript = text + (UserDefaults.standard.string(forKey: "transcriptionSuffix") ?? "")
                print("📝 Transcription:", text)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(lastTranscript, forType: .string)
            } catch {
                print("❌ Transcription error:", error)
            }
        }
    }

}
