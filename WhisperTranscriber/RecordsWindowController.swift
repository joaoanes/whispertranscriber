import SwiftUI
import AppKit

class RecordsWindowController: NSWindowController, NSWindowDelegate {
    var onWindowClose: (() -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("Records")
        window.contentView = NSHostingView(rootView: RecordsView())
        window.isReleasedWhenClosed = true
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        onWindowClose?()
    }
}