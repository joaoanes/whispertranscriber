import SwiftUI

struct RecordsView: View {
    static let windowID = "records"

    @StateObject private var viewModel = RecordsViewModel()

    var body: some View {
        Group {
            if viewModel.displayableRecordings.isEmpty {
                ContentUnavailableView(
                    "No Recordings",
                    systemImage: "waveform",
                    description: Text("Recordings appear here after you use the shortcut.")
                )
            } else {
                List(viewModel.displayableRecordings) { recording in
                    RecordingRowView(recording: recording)
                        .contextMenu {
                            Button("Copy Transcript", systemImage: "doc.on.doc") {
                                viewModel.copyTranscript(of: recording)
                            }
                            .disabled(recording.transcription == nil)
                            Button("Re-transcribe", systemImage: "arrow.clockwise") {
                                viewModel.retranscribe(recording: recording)
                            }
                            .disabled(viewModel.isTranscribing)
                            Divider()
                            Button("Show in Finder", systemImage: "folder") {
                                viewModel.reveal(recording)
                            }
                        }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Open in Finder", systemImage: "folder") {
                    viewModel.openRecordingsFolder()
                }
                .help("Open the recordings folder in Finder")
                .disabled(viewModel.recordingsManager.recordingsDirectory == nil)
            }
        }
        .onAppear {
            viewModel.refresh()
        }
        .frame(minWidth: 420, minHeight: 400)
    }
}

#Preview {
    RecordsView()
}
