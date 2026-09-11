import XCTest
@testable import LanGuardFeature

final class AutoJoinControlTests: XCTestCase {
    private final class State {
        var disabled = false
        var owned = false
        var fail = false
        var ignoreWrite = false
        var calls: [Bool] = []
        func control() -> AutoJoinControl {
            AutoJoinControl(dependencies: .init(
                isDisabled: { self.disabled },
                setDisabled: {
                    XCTAssertTrue(self.owned, "Journal must precede mutation")
                    if self.fail { throw AutoJoinControl.ControlError.failed }
                    self.calls.append($0)
                    if !self.ignoreWrite { self.disabled = $0 }
                },
                loadOwned: { self.owned }, saveOwned: { self.owned = $0 }
            ))
        }
    }
    func testAcquireReleaseAndIdempotency() throws {
        let state = State(); let control = state.control()
        XCTAssertTrue(try control.renew())
        XCTAssertFalse(try control.renew())
        try control.release()
        try control.release()
        XCTAssertEqual(state.calls, [true, false])
        XCTAssertFalse(state.owned)
    }
    func testPreservesPreexistingPause() throws {
        let state = State(); state.disabled = true
        let control = state.control()
        XCTAssertFalse(try control.renew())
        try control.release()
        XCTAssertTrue(state.disabled)
        XCTAssertTrue(state.calls.isEmpty)
    }
    func testCrashRecoveryFromPersistedOwnership() throws {
        let state = State()
        try state.control().renew()
        try state.control().release()
        XCTAssertFalse(state.disabled)
        XCTAssertFalse(state.owned)
    }
    func testFailedRestoreKeepsRecoveryRecord() throws {
        let state = State(); let control = state.control()
        try control.renew()
        state.fail = true
        XCTAssertThrowsError(try control.release())
        XCTAssertTrue(state.owned)
        state.fail = false
        try state.control().release()
        XCTAssertFalse(state.disabled)
    }
    func testFailedAcquireDoesNotClaimAnUnchangedSystem() {
        let state = State(); state.fail = true
        XCTAssertThrowsError(try state.control().renew())
        XCTAssertFalse(state.owned)
    }
    func testDetectsIgnoredWriteAndSystemReset() throws {
        let state = State(); let control = state.control()
        state.ignoreWrite = true
        XCTAssertThrowsError(try control.renew())
        state.ignoreWrite = false
        try control.renew()
        state.disabled = false
        XCTAssertTrue(try control.renew())
        XCTAssertTrue(state.disabled)
    }

    private final class Client: NSObject {
        var disabled = false
        var fail = false
        @objc func activate() {}
        @objc func invalidate() {}
        @objc func interfaceName() -> NSString { "en0" }
        @objc func userAutoJoinDisabled() -> Bool { disabled }
        @objc(setUserAutoJoinDisabled:error:)
        func setDisabled(_ value: Bool, error: AutoreleasingUnsafeMutablePointer<NSError?>) -> Bool {
            if fail {
                error.pointee = NSError(domain: "LanGuardBridgeTest", code: 1)
                return false
            }
            disabled = value
            return true
        }
    }

    func testBridgeErrorsSurviveAutoreleasePoolDrain() throws {
        let name = "lg-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let client = Client()
        let control = try AutoJoinControl.system(client: client, defaults: defaults)
        client.fail = true
        for _ in 0..<100 {
            try autoreleasepool {
                XCTAssertThrowsError(try control.renew()) {
                    XCTAssertEqual(($0 as NSError).domain, "LanGuardBridgeTest")
                }
            }
        }
        client.fail = false
        _ = try autoreleasepool { try control.renew() }
        client.fail = true
        try autoreleasepool { XCTAssertThrowsError(try control.release()) }
        client.fail = false
        try AutoJoinControl.system(client: client, defaults: defaults).release()
        XCTAssertFalse(client.disabled)
    }

    func testRejectsOtherAdaptersWithoutMutating() throws {
        let client = Client()
        XCTAssertThrowsError(try AutoJoinControl.system(interfaces: ["en9"], client: client))
        XCTAssertFalse(client.disabled)
    }
    func testSettingDefaultsOffAndPersists() {
        let name = "lg-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.keepWiFiOn)
        settings.keepWiFiOn = true
        XCTAssertTrue(AppSettings(defaults: defaults).keepWiFiOn)
    }

    func testDisconnectModeStopClearsPauseEvenOnReleaseError() throws {
        let state = State()
        let mode = DisconnectMode(makeControl: { _ in state.control() })
        // Begin sets up pause
        try mode.begin(interfaces: ["en0"])
        XCTAssertTrue(mode.isActive)

        // Fail release on stop
        state.fail = true
        mode.stop()
        // Must clear pause despite release error (no leak)
        XCTAssertFalse(mode.isActive)
        XCTAssertNotNil(mode.errorMessage)
    }

    func testDisconnectModeBeginRethrowsErrorForFallback() {
        let mode = DisconnectMode(makeControl: { _ in
            throw AutoJoinControl.ControlError.interfaceUnsupported
        })
        XCTAssertThrowsError(try mode.begin(interfaces: ["en0", "en1"])) { error in
            XCTAssertEqual(error as? AutoJoinControl.ControlError, .interfaceUnsupported)
        }
        XCTAssertFalse(mode.isActive)
        XCTAssertNotNil(mode.errorMessage)
    }
}
