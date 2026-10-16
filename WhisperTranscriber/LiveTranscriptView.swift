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
            segment.text.sentences.enumerated().map { index, sentence in
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
}

extension NSAttributedString.Key {
    static let transcriptTimestamp = NSAttributedString.Key("WhisperTranscriber.transcriptTimestamp")
}

enum TranscriptDocument {
    static let gutterWidth: CGFloat = 40
    static let timestampFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)

    static func build(_ lines: [RecencyLine]) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = gutterWidth
        paragraph.headIndent = gutterWidth
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 4

        let document = NSMutableAttributedString()
        for (index, line) in lines.enumerated() {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: line.fontSize, weight: line.isNewest ? .medium : .regular),
                .foregroundColor: color(forAge: line.age),
                .paragraphStyle: paragraph
            ]
            attributes[.transcriptTimestamp] = line.timestamp
            document.append(NSAttributedString(
                string: line.text + (index == lines.count - 1 ? "" : "\n"),
                attributes: attributes
            ))
        }
        return document
    }

    static func timestamps(in document: NSAttributedString) -> [(location: Int, text: String)] {
        var timestamps: [(location: Int, text: String)] = []
        document.enumerateAttribute(
            .transcriptTimestamp,
            in: NSRange(location: 0, length: document.length)
        ) { value, run, _ in
            guard let text = value as? String else { return }
            timestamps.append((run.location, text))
        }
        return timestamps
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
    var bottomPadding: CGFloat = 0 {
        didSet { if bottomPadding != oldValue { needsDisplay = true } }
    }

    override var textContainerOrigin: NSPoint {
        NSPoint(x: 0, y: bottomPadding)
    }

    var contentHeight: CGFloat {
        guard let layoutManager, let textContainer else { return 0 }
        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.usedRect(for: textContainer).height
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let layoutManager, let textStorage else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: TranscriptDocument.timestampFont,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        for timestamp in TranscriptDocument.timestamps(in: textStorage) {
            let glyph = layoutManager.glyphIndexForCharacter(at: timestamp.location)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let baseline = layoutManager.location(forGlyphAt: glyph).y
            let origin = NSPoint(
                x: 0,
                y: fragment.minY + textContainerOrigin.y + baseline - TranscriptDocument.timestampFont.ascender
            )
            NSAttributedString(string: timestamp.text, attributes: attributes).draw(at: origin)
        }
    }
}

final class TranscriptScrollView: NSScrollView {
    private let fade = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        fade.colors = [NSColor.clear.cgColor, NSColor.black.cgColor]
        fade.locations = [0, 0.15]
        fade.startPoint = CGPoint(x: 0.5, y: 1)
        fade.endPoint = CGPoint(x: 0.5, y: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tile() {
        super.tile()
        guard let textView = documentView as? TranscriptTextView else { return }

        let viewport = contentSize.height
        let content = textView.contentHeight
        textView.bottomPadding = max(0, viewport - content)
        textView.minSize = NSSize(width: 0, height: viewport)
        textView.frame.size.width = contentSize.width
        textView.sizeToFit()

        fade.frame = bounds
        layer?.mask = content > viewport ? fade : nil
    }
}

struct TranscriptTextRepresentable: NSViewRepresentable {
    let lines: [RecencyLine]

    func makeNSView(context: Context) -> TranscriptScrollView {
        let textView = TranscriptTextView(usingTextLayoutManager: false)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scrollView = TranscriptScrollView(frame: .zero)
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ scrollView: TranscriptScrollView, context: Context) {
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
        scrollView.tile()
        textView.scrollToEndOfDocument(nil)
        textView.needsDisplay = true
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
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .bottomLeading)
            } else {
                TranscriptTextRepresentable(lines: lines)
                    .frame(height: 140)
            }
        }
    }
}
