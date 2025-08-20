import SwiftUI

struct LogView: View {
    @StateObject private var logStore = LogStore.shared

    var body: some View {
        ScrollView {
            Text(logStore.logMessages.joined())
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
