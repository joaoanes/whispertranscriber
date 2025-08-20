import Foundation
import Combine
import AVFoundation

struct DisplayableRecording: Identifiable, Hashable {
    let id: URL
    let fileName: String
    let creationDate: String
    let duration: String
    let transcription: String?
}

@MainActor
class RecordsViewModel: ObservableObject {
    @Published var displayableRecordings: [DisplayableRecording] = []

    let recordingsManager = RecordingsManager.shared
    private let recorderViewModel = RecorderViewModel.shared

    private var cancellables = Set<AnyCancellable>()

    init() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        recordingsManager.$recordings
            .combineLatest(recordingsManager.$transcriptions)
            .map { urls, transcriptions in
                urls.map { url in
                    let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
                    return DisplayableRecording(
                        id: url,
                        fileName: url.lastPathComponent,
                        creationDate: dateFormatter.string(from: creationDate),
                        duration: "…",
                        transcription: transcriptions[url]
                    )
                }
            }
            .sink { [weak self] displayableRecordings in
                self?.displayableRecordings = displayableRecordings
                self?.updateDurations()
            }
            .store(in: &cancellables)
    }

    private func getAudioDuration(for url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            return nil
        }
        let durationInSeconds = CMTimeGetSeconds(duration)

        if durationInSeconds.isNaN || durationInSeconds.isInfinite {
            return nil
        }

        let minutes = Int(durationInSeconds) / 60
        let seconds = Int(durationInSeconds) % 60

        return String(format: "%d:%02d", minutes, seconds)
    }

    private func updateDurations() {
        Task {
            for (index, recording) in displayableRecordings.enumerated() {
                async let duration = getAudioDuration(for: recording.id)
                if let duration = await duration {
                    DispatchQueue.main.async {
                        self.displayableRecordings[index] = .init(
                            id: recording.id,
                            fileName: recording.fileName,
                            creationDate: recording.creationDate,
                            duration: duration,
                            transcription: recording.transcription
                        )
                    }
                }
            }
        }
    }

    var isTranscribing: Bool {
        recorderViewModel.isTranscribing
    }

    func retranscribe(recording: DisplayableRecording) {
        recorderViewModel.retranscribe(url: recording.id)
    }

    func refresh() {
        recordingsManager.scanForRecordings()
    }
}
