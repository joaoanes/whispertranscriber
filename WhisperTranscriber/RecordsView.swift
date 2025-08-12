import SwiftUI

struct RecordsView: View {
    @StateObject private var viewModel = RecordsViewModel()

    var body: some View {
        VStack {
            if viewModel.displayableRecordings.isEmpty {
                Text("No recordings yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.displayableRecordings) { recording in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recording.fileName)
                            .font(.headline)

                        Text(recording.creationDate)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let transcription = recording.transcription {
                            Text(transcription)
                                .font(.body)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        } else {
                            Text("Transcription not available for this session.")
                                .italic()
                                .foregroundColor(.secondary)
                        }

                        Button("Re-transcribe") {
                            viewModel.retranscribe(recording: recording)
                        }
                        .disabled(viewModel.isTranscribing)
                    }
                    .padding(.vertical, 4)
                }
            }

            Button("Refresh List") {
                viewModel.refresh()
            }
            .padding()

            Text("Watching folder: \(viewModel.recordingsManager.cacheDirectory.path)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .onAppear {
            viewModel.refresh()
        }
        .frame(minWidth: 400, minHeight: 400)
    }
}

struct RecordsView_Previews: PreviewProvider {
    static var previews: some View {
        RecordsView()
    }
}
