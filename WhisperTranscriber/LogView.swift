import SwiftUI

struct LogView: View {
    @StateObject private var logStore = LogStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(logStore.logMessages, id: \.self) { message in
                    Text(message)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
