import SwiftUI

class RecordsWindowController: NSObject, NSWindowDelegate {
    static let shared = RecordsWindowController()
    private var recordsWindow: NSWindow

    private override init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("Records")
        window.contentView = NSHostingView(rootView: RecordsView())
        window.isReleasedWhenClosed = false
        self.recordsWindow = window
        super.init()
        window.delegate = self
    }

    func showWindow() {
        recordsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Window is hidden instead of closed, keeping the view hierarchy alive
    }
}
