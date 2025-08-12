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
            .map { [weak self] urls, transcriptions in
                guard let self = self else { return [] }
                return urls.map { url in
                    let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
                    let duration = self.getAudioDuration(for: url) ?? "0:00"
                    return DisplayableRecording(
                        id: url,
                        fileName: url.lastPathComponent,
                        creationDate: dateFormatter.string(from: creationDate),
                        duration: duration,
                        transcription: transcriptions[url]
                    )
                }
            }
            .sink { [weak self] displayableRecordings in
                self?.displayableRecordings = displayableRecordings
            }
            .store(in: &cancellables)
    }

    private func getAudioDuration(for url: URL) -> String? {
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        let durationInSeconds = CMTimeGetSeconds(duration)

        if durationInSeconds.isNaN || durationInSeconds.isInfinite {
            return nil
        }

        let minutes = Int(durationInSeconds) / 60
        let seconds = Int(durationInSeconds) % 60

        return String(format: "%d:%02d", minutes, seconds)
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
