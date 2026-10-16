import SwiftUI

struct RecordingRowView: View {
    let recording: DisplayableRecording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let transcription = recording.transcription {
                Text(transcription)
                    .lineLimit(2)
            } else {
                Text("No transcript")
                    .italic()
                    .foregroundStyle(.tertiary)
            }

            Text("\(recording.creationDate) · \(recording.duration)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
