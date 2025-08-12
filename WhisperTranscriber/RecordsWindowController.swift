import SwiftUI

class RecordsWindowController: NSObject, NSWindowDelegate {
    static let shared = RecordsWindowController()
    var recordsWindow: NSWindow?

    private override init() {
        super.init()
    }

    func showWindow() {
        if recordsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.setFrameAutosaveName("Records")
            window.contentView = NSHostingView(rootView: RecordsView())
            window.delegate = self
            window.isReleasedWhenClosed = false // We manage the lifecycle now
            self.recordsWindow = window
        }

        recordsWindow?.makeKeyAndOrderFront(nil)
        // Also ensure the app becomes active to bring the window to the front
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // We just hide the window instead of closing it.
        // The window object and its view hierarchy are kept alive.
    }
}
