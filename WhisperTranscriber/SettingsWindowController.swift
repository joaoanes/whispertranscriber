import SwiftUI

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    var settingsWindow: NSWindow?

    private override init() {
        super.init()
    }

    func showWindow() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.setFrameAutosaveName("Settings")
            window.contentView = NSHostingView(rootView: WhisperTranscriberView())
            window.delegate = self
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
            window.title = "Settings"
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Hide the window instead of closing it, so we can show it again.
        (notification.object as? NSWindow)?.orderOut(nil)
    }
}
