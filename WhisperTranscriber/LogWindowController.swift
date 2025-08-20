import SwiftUI
import AppKit

class LogWindowController: NSWindowController {
    static let shared = LogWindowController()

    private var logWindow: NSWindow?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("LogWindow")
        window.title = "App Logs"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: LogView())
        super.init(window: window)
        self.logWindow = window
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle() {
        if logWindow?.isVisible == true {
            logWindow?.orderOut(nil)
        } else {
            logWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
