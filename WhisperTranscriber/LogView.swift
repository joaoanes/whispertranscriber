import SwiftUI

struct LogTextView: NSViewRepresentable {
    var logMessages: [LogMessage]

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        let newText = logMessages.map { $0.message }.joined(separator: "\n")

        let shouldScroll = textView.visibleRect.maxY >= textView.bounds.maxY - 10

        if textView.string != newText {
            textView.string = newText
            if shouldScroll {
                textView.scrollToEndOfDocument(nil)
            }
        }
    }
}

struct LogView: View {
    @StateObject private var logStore = LogStore.shared

    var body: some View {
        LogTextView(logMessages: logStore.logMessages)
            .frame(minWidth: 600, minHeight: 400)
    }
}
