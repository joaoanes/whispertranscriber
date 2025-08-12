import SwiftUI

struct RecordingRowView: View {
    let recording: DisplayableRecording
    let retranscribeAction: () -> Void

    @State private var copyButtonText: String = "Copy"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recording.fileName)
                    .font(.headline)
                Spacer()
                Text(recording.duration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(recording.creationDate)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let transcription = recording.transcription {
                Text(transcription)
                    .font(.body)
                    .lineLimit(3)

                HStack {
                    Button(action: {
                        copyToClipboard(text: transcription)
                    }) {
                        Text(copyButtonText)
                    }

                    Spacer()

                    Button("Re-transcribe", action: retranscribeAction)
                }

            } else {
                Text("Transcription not available for this session.")
                    .italic()
                    .foregroundColor(.secondary)

                Button("Re-transcribe", action: retranscribeAction)
            }
        }
        .padding(.vertical, 4)
    }

    private func copyToClipboard(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copyButtonText = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copyButtonText = "Copy"
        }
    }
}
