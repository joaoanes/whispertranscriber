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
                    RecordingRowView(recording: recording) {
                        viewModel.retranscribe(recording: recording)
                    }
                    .disabled(viewModel.isTranscribing)
                }
            }

            Button("Refresh List") {
                viewModel.refresh()
            }
            .padding()

            Text("Watching folder: \(viewModel.recordingsManager.recordingsDirectory?.path() ?? "no path found")")
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
