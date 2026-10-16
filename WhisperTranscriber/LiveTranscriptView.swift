import AppKit
import SwiftUI

struct RecencyLine: Identifiable, Equatable {
    let id: Int
    let text: String
    let age: Int
    let startsAt: TimeInterval?

    var isNewest: Bool { age == 0 }

    var fontSize: CGFloat {
        switch age {
        case 0: 17
        case 1: 13
        default: 11
        }
    }

    var timestamp: String? {
        startsAt.map(Self.format)
    }

    static func lines(in segments: [LiveSegment]) -> [RecencyLine] {
        let sentences = segments.flatMap { segment in
            sentences(in: segment.text).enumerated().map { index, sentence in
                (text: sentence, startsAt: index == 0 ? segment.startsAt : nil)
            }
        }
        return sentences.enumerated().map { index, sentence in
            RecencyLine(
                id: index,
                text: sentence.text,
                age: sentences.count - 1 - index,
                startsAt: sentence.startsAt
            )
        }
    }

    static func format(_ elapsed: TimeInterval) -> String {
        let pattern: Duration.TimeFormatStyle.Pattern = elapsed < 3600 ? .minuteSecond : .hourMinuteSecond
        return Duration.seconds(Int(elapsed)).formatted(.time(pattern: pattern))
    }

    private static func sentences(in transcript: String) -> [String] {
        var sentences: [String] = []
        transcript.enumerateSubstrings(
            in: transcript.startIndex..<transcript.endIndex,
            options: .bySentences
        ) { sentence, _, _, _ in
            guard let trimmed = sentence?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty
            else { return }
            sentences.append(trimmed)
        }
        return sentences
    }
}

extension NSAttributedString.Key {
    static let transcriptGutter = NSAttributedString.Key("WhisperTranscriber.transcriptGutter")
}

enum TranscriptDocument {
    static let gutterWidth: CGFloat = 40

    static func build(_ lines: [RecencyLine]) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: gutterWidth)]
        paragraph.headIndent = gutterWidth
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 4

        let document = NSMutableAttributedString()
        for (index, line) in lines.enumerated() {
            document.append(NSAttributedString(
                string: (line.timestamp ?? "") + "\t",
                attributes: [
                    .transcriptGutter: true,
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: NSColor.tertiaryLabelColor,
                    .paragraphStyle: paragraph
                ]
            ))
            document.append(NSAttributedString(
                string: line.text + (index == lines.count - 1 ? "" : "\n"),
                attributes: [
                    .font: NSFont.systemFont(ofSize: line.fontSize, weight: line.isNewest ? .medium : .regular),
                    .foregroundColor: color(forAge: line.age),
                    .paragraphStyle: paragraph
                ]
            ))
        }
        return document
    }

    static func copyableText(in document: NSAttributedString, ranges: [NSRange]) -> String {
        ranges.map { range in
            var text = ""
            document.enumerateAttribute(.transcriptGutter, in: range) { gutter, run, _ in
                guard gutter == nil else { return }
                text += document.attributedSubstring(from: run).string
            }
            return text
        }
        .joined(separator: "\n")
    }

    private static func color(forAge age: Int) -> NSColor {
        switch age {
        case 0: .labelColor
        case 1: .secondaryLabelColor
        default: .tertiaryLabelColor
        }
    }
}

final class TranscriptTextView: NSTextView {
    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        guard let textStorage else { return false }
        let text = TranscriptDocument.copyableText(
            in: textStorage,
            ranges: selectedRanges.map(\.rangeValue)
        )
        pboard.clearContents()
        return pboard.setString(text, forType: .string)
    }
}

struct TranscriptTextRepresentable: NSViewRepresentable {
    let lines: [RecencyLine]

    func makeNSView(context: Context) -> NSScrollView {
        let textView = TranscriptTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? TranscriptTextView,
              let textStorage = textView.textStorage
        else { return }

        let document = TranscriptDocument.build(lines)
        guard !textStorage.isEqual(to: document) else { return }

        let selection = textView.selectedRanges
        textStorage.setAttributedString(document)
        let length = textStorage.length
        let survivingSelection = selection.filter { NSMaxRange($0.rangeValue) <= length }
        if !survivingSelection.isEmpty {
            textView.selectedRanges = survivingSelection
        }
        textView.scrollToEndOfDocument(nil)
    }
}

struct LiveTranscriptView: View {
    let segments: [LiveSegment]

    private var lines: [RecencyLine] {
        RecencyLine.lines(in: segments)
    }

    private var wordCount: Int {
        segments.text.split(whereSeparator: \.isWhitespace).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transcript")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if wordCount > 0 {
                    Text("\(wordCount) words")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            if segments.isEmpty {
                Text("Listening…")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            } else {
                TranscriptTextRepresentable(lines: lines)
                    .frame(height: 140)
                    .mask(
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}
