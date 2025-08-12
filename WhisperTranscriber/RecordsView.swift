import SwiftUI

struct RecordsView: View {
    @StateObject private var recordingsManager = RecordingsManager.shared
    @StateObject private var vm = RecorderViewModel.shared

    var body: some View {
        VStack {
            if recordingsManager.recordings.isEmpty {
                Text("No recordings yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(recordingsManager.recordings, id: \.self) { url in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(url.lastPathComponent)
                                .font(.headline)

                            if let creationDate = getCreationDate(for: url) {
                                Text(creationDate, style: .dateTime)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            if let transcription = recordingsManager.transcriptions[url] {
                                Text(transcription)
                                    .font(.body)
                                    .lineLimit(3)
                            } else {
                                Text("Transcription not available for this session.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Button("Re-transcribe") {
                                vm.retranscribe(url: url)
                            }
                            .disabled(vm.isTranscribing)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Button("Refresh List") {
                recordingsManager.scanForRecordings()
            }
            .padding()
        }
        .onAppear {
            recordingsManager.scanForRecordings()
        }
        .frame(minWidth: 400, minHeight: 400)
    }

    private func getCreationDate(for url: URL) -> Date? {
        do {
            let values = try url.resourceValues(forKeys: [.creationDateKey])
            return values.creationDate
        } catch {
            print("Error getting creation date for \(url.path): \(error)")
            return nil
        }
    }
}

struct RecordsView_Previews: PreviewProvider {
    static var previews: some View {
        RecordsView()
    }
}
