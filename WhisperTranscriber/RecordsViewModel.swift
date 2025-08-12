import Foundation
import Combine

struct DisplayableRecording: Identifiable, Hashable {
    let id: URL
    let fileName: String
    let creationDate: String
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
                return urls.map { url in
                    let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
                    return DisplayableRecording(
                        id: url,
                        fileName: url.lastPathComponent,
                        creationDate: dateFormatter.string(from: creationDate),
                        transcription: transcriptions[url]
                    )
                }
            }
            .sink { [weak self] displayableRecordings in
                self?.displayableRecordings = displayableRecordings
            }
            .store(in: &cancellables)
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
