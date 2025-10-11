import SwiftUI
import AppKit

class LogWindowController: NSWindowController, NSWindowDelegate {
    var onWindowClose: (() -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("LogWindow")
        window.title = "App Logs"
        window.isReleasedWhenClosed = true
        window.contentView = NSHostingView(rootView: LogView())
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