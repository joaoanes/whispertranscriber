import Foundation
import AVFoundation
import WhisperKit
import AppKit

@MainActor
class RecorderViewModel: ObservableObject {
    static let shared = RecorderViewModel()

    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false

    private var recorder: AVAudioRecorder?
    private var whisperKit: WhisperKit?
    private var lastTranscript = ""

    private init() {
        Task {
            whisperKit = try? await WhisperKit()
        }
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
        // AVAudioRecorder.isRecording becomes false after stop()
        isRecording = recorder?.isRecording ?? false
        isTranscribing = true

        guard let url = recorder?.url else {
            print("❌ No audio file URL")
            return
        }
        print("⏹️ Stopped. File at:", url.path)

        Task {
            defer { isTranscribing = false }
            guard let kit = whisperKit else {
                print("❌ WhisperKit not ready")
                return
            }
            do {
                let results = try await kit.transcribe(audioPath: url.path)
                let text = results.first?.text ?? ""
                lastTranscript = text
                print("📝 Transcription:", text)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            } catch {
                print("❌ Transcription error:", error)
            }
        }
    }

    func copyLastTranscript() {
        guard !lastTranscript.isEmpty else {
            print("⚠️ No transcript to copy")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
        print("📋 Copied last transcript")
    }

    func clearCache() {
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first!
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: caches,
                includingPropertiesForKeys: nil
            )
            for file in files where file.lastPathComponent.hasPrefix("recording_") {
                try FileManager.default.removeItem(at: file)
            }
            print("🗑️ Cleared cache")
        } catch {
            print("❌ Failed to clear cache:", error)
        }
    }

    // MARK: - Helpers

    private func requestMicPermission(_ cb: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            cb(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                cb(granted)
            }
        default:
            cb(false)
        }
    }

    private func tempURL() -> URL {
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first!
        let name = "recording_\(Int(Date().timeIntervalSince1970)).wav"
        return caches.appendingPathComponent(name)
    }
}
