import SwiftUI
import AppKit

/// A SwiftUI wrapper around a custom NSView that captures a single key chord
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var chord: String
    var onChordCaptured: (String) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let v = KeyCaptureView()
        v.onChordCaptured = { new in
            onChordCaptured(new)
            // drop focus immediately
            DispatchQueue.main.async { v.window?.makeFirstResponder(nil) }
        }
        return v
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.chordToShow = chord
        nsView.needsDisplay = true
    }

    class KeyCaptureView: NSView {
        var chordToShow: String = ""
        var onChordCaptured: ((String) -> Void)?

        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.cornerRadius = 4
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = true
            layer?.cornerRadius = 4
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            // highlight border when focused
            if window?.firstResponder === self {
                layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
            } else {
                layer?.borderColor = NSColor.separatorColor.cgColor
            }

            // draw the chord text centered
            let attrs: [NSAttributedString.Key:Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
            let str = NSAttributedString(string: chordToShow, attributes: attrs)
            let size = str.size()
            // small horizontal padding
            let x = 6.0
            let y = (bounds.height - size.height)/2
            str.draw(at: .init(x: x, y: y))
        }

        override func mouseDown(with event: NSEvent) {
            // one click → grab focus
            _ = becomeFirstResponder()
        }

        override func becomeFirstResponder() -> Bool {
            let ok = super.becomeFirstResponder()
            needsDisplay = true
            return ok
        }

        override func resignFirstResponder() -> Bool {
            let ok = super.resignFirstResponder()
            needsDisplay = true
            return ok
        }

        override func keyDown(with event: NSEvent) {
            // capture modifiers + key
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let chars = event.charactersIgnoringModifiers?.uppercased() ?? ""
            guard let c = chars.first else { return }
            let parts: [String] = [
                flags.contains(.control) ? "⌃" : "",
                flags.contains(.option)  ? "⌥" : "",
                flags.contains(.shift)   ? "⇧" : "",
                flags.contains(.command) ? "⌘" : "",
                String(c)
            ].filter { !$0.isEmpty }
            onChordCaptured?(parts.joined())
        }

        override var intrinsicContentSize: NSSize {
            // a bit wider to accommodate padding
            .init(width: 100, height: 24)
        }
    }
}
