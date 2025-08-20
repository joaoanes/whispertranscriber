import SwiftUI

class AboutWindowController: NSObject, NSWindowDelegate {
    static let shared = AboutWindowController()
    var aboutWindow: NSWindow?

    private override init() {
        super.init()
    }

    func showWindow() {
        if aboutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.setFrameAutosaveName("About")
            window.contentView = NSHostingView(rootView: AboutView())
            window.delegate = self
            window.isReleasedWhenClosed = false
            self.aboutWindow = window
            window.title = "About WhisperTranscriber"
        }

        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Hide the window instead of closing it.
        (notification.object as? NSWindow)?.orderOut(nil)
    }
}
