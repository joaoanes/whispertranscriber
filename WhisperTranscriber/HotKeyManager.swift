import Carbon

typealias HotKeyHandler = () -> Void

final class HotKeyManager {
    private static var hotKeyRefs: [EventHotKeyRef] = []
    public static var handlers: [UInt32: HotKeyHandler] = [:]
    private static var handlerInstalled = false

    static func register(
        keyCode: UInt32,
        modifiers: UInt32,
        id: UInt32,
        handler: @escaping HotKeyHandler
    ) {
        handlers[id] = handler

        let hotKeyID = EventHotKeyID(
            signature: UTGetOSTypeFromString("SwHK"),
            id: id
        )
        var hotKeyRef: EventHotKeyRef?

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if let ref = hotKeyRef {
            hotKeyRefs.append(ref)
        }

        if !handlerInstalled {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind:  UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(
                GetEventDispatcherTarget(),
                hotKeyEventHandler,
                1,
                &eventType,
                nil,
                nil
            )
            handlerInstalled = true
        }
    }

    static func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
    }
}

private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event:       EventRef?,
    _ userData:    UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    GetEventParameter(
        event,
        UInt32(kEventParamDirectObject),
        UInt32(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if let handler = HotKeyManager.handlers[hotKeyID.id] {
        DispatchQueue.main.async {
            handler()
        }
    }

    return noErr
}
