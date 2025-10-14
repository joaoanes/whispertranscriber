import SwiftUI

struct LogView: View {
    @StateObject private var logStore = LogStore.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(logStore.logMessages) { logMessage in
                    Text(logMessage.message)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .textSelection(.enabled)
    }
}
