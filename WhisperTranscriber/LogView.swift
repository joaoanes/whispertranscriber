import SwiftUI

struct LogView: View {
    @ObservedObject private var logStore = LogStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header with log count
            HStack {
                Text("Logs (\(logStore.logMessages.count) messages - limited to 100)")
                    .font(.headline)
                Spacer()
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            // Virtualized scroll view with messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(logStore.logMessages) { message in
                        Text(message.message)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
