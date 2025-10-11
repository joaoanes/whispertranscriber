import XCTest
import Carbon
@testable import WhisperTranscriber

final class HotKeyManagerTests: XCTestCase {

    var hotKeyManager: HotKeyManager!

    override func setUp() {
        super.setUp()
        hotKeyManager = HotKeyManager.shared
    }

    override func tearDown() {
        hotKeyManager.unregister()
        super.tearDown()
    }

    func testRegisterWithOptionCommandS() {
        var handlerCalled = false
        let handler: HotKeyHandler = {
            handlerCalled = true
        }

        let success = hotKeyManager.register(chord: "⌥⌘S", handler: handler)

        XCTAssertTrue(success)
    }

    func testRegisterWithCommandR() {
        var handlerCalled = false
        let handler: HotKeyHandler = {
            handlerCalled = true
        }

        let success = hotKeyManager.register(chord: "⌘R", handler: handler)

        XCTAssertTrue(success)
    }

    func testRegisterWithControlShiftT() {
        var handlerCalled = false
        let handler: HotKeyHandler = {
            handlerCalled = true
        }

        let success = hotKeyManager.register(chord: "⌃⇧T", handler: handler)

        XCTAssertTrue(success)
    }

    func testRegisterWithDigit() {
        var handlerCalled = false
        let handler: HotKeyHandler = {
            handlerCalled = true
        }

        let success = hotKeyManager.register(chord: "⌘1", handler: handler)

        XCTAssertTrue(success)
    }

    func testRegisterWithInvalidChordFails() {
        let handler: HotKeyHandler = {}

        let success = hotKeyManager.register(chord: "⌘", handler: handler)

        XCTAssertFalse(success)
    }

    func testRegisterWithNoLetterOrDigitFails() {
        let handler: HotKeyHandler = {}

        let success = hotKeyManager.register(chord: "⌘⌥", handler: handler)

        XCTAssertFalse(success)
    }

    func testUnregisterRemovesHotKey() {
        let handler: HotKeyHandler = {}
        hotKeyManager.register(chord: "⌘T", handler: handler)

        hotKeyManager.unregister()

        let newRegistration = hotKeyManager.register(chord: "⌘T", handler: handler)
        XCTAssertTrue(newRegistration)
    }

    func testRegisterReplacesExistingHotKey() {
        var firstHandlerCalled = false
        var secondHandlerCalled = false

        let firstHandler: HotKeyHandler = {
            firstHandlerCalled = true
        }
        let secondHandler: HotKeyHandler = {
            secondHandlerCalled = true
        }

        hotKeyManager.register(chord: "⌘A", handler: firstHandler)
        let success = hotKeyManager.register(chord: "⌘B", handler: secondHandler)

        XCTAssertTrue(success)
    }

    func testRegisterWithLowercaseLetterSucceeds() {
        let handler: HotKeyHandler = {}

        let success = hotKeyManager.register(chord: "⌘s", handler: handler)

        XCTAssertTrue(success)
    }

    func testRegisterWithUppercaseLetterSucceeds() {
        let handler: HotKeyHandler = {}

        let success = hotKeyManager.register(chord: "⌘S", handler: handler)

        XCTAssertTrue(success)
    }

    func testRegisterWithAllModifiers() {
        let handler: HotKeyHandler = {}

        let success = hotKeyManager.register(chord: "⌘⌥⌃⇧X", handler: handler)

        XCTAssertTrue(success)
    }
}
