import XCTest
import IOKit.pwr_mgt
@testable import ClaudeKeepAwake

final class AppStateTests: XCTestCase {

    private func freshDefaults(_ suite: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testEnableDisableTogglesIsKeepAwakeActive() {
        let state = AppState(defaults: freshDefaults(#function))
        XCTAssertFalse(state.isKeepAwakeActive)

        state.enableKeepAwake()
        XCTAssertTrue(state.isKeepAwakeActive)
        XCTAssertNil(state.lastErrorMessage)

        state.disableKeepAwake()
        XCTAssertFalse(state.isKeepAwakeActive)
    }

    func testToggleKeepAwakeFlipsState() {
        let state = AppState(defaults: freshDefaults(#function))
        state.toggleKeepAwake()
        XCTAssertTrue(state.isKeepAwakeActive)
        state.toggleKeepAwake()
        XCTAssertFalse(state.isKeepAwakeActive)
    }

    func testRepeatedEnableDisableStaysConsistent() {
        let state = AppState(defaults: freshDefaults(#function))
        for _ in 0..<5 {
            state.enableKeepAwake()
            XCTAssertTrue(state.isKeepAwakeActive)
            state.disableKeepAwake()
            XCTAssertFalse(state.isKeepAwakeActive)
        }
    }

    func testEnableFailureSurfacesErrorAndLeavesInactive() {
        let fake = FakeAssertionProvider()
        fake.nextCreateResult = kIOReturnError
        let state = AppState(sleepManager: SleepManager(provider: fake), defaults: freshDefaults(#function))

        state.enableKeepAwake()

        XCTAssertFalse(state.isKeepAwakeActive)
        XCTAssertNotNil(state.lastErrorMessage)
    }

    func testDismissBatteryWarningClearsFlag() {
        let state = AppState(defaults: freshDefaults(#function))
        state.showBatteryWarning = true
        state.dismissBatteryWarning()
        XCTAssertFalse(state.showBatteryWarning)
    }

    func testDisablingKeepAwakeClearsBatteryWarning() {
        let state = AppState(defaults: freshDefaults(#function))
        state.enableKeepAwake()
        state.showBatteryWarning = true

        state.disableKeepAwake()

        XCTAssertFalse(state.showBatteryWarning)
    }

    // MARK: - Settings persistence

    func testStartActiveSettingPersistsAcrossInstances() {
        let defaults = freshDefaults(#function)
        XCTAssertFalse(AppState(defaults: defaults).startActiveSetting, "default is off")

        let state1 = AppState(defaults: defaults)
        state1.startActiveSetting = true

        let state2 = AppState(defaults: defaults)
        XCTAssertTrue(state2.startActiveSetting)
    }

    func testBatteryWarningEnabledPersistsAcrossInstances() {
        let defaults = freshDefaults(#function)
        XCTAssertTrue(AppState(defaults: defaults).batteryWarningEnabled, "default is on")

        let state1 = AppState(defaults: defaults)
        state1.batteryWarningEnabled = false

        let state2 = AppState(defaults: defaults)
        XCTAssertFalse(state2.batteryWarningEnabled)
    }

    // MARK: - Start Active on launch

    func testStartCallsEnableWhenStartActiveSettingIsTrue() {
        let defaults = freshDefaults(#function)
        let seed = AppState(defaults: defaults)
        seed.startActiveSetting = true

        let fake = FakeAssertionProvider()
        let state = AppState(sleepManager: SleepManager(provider: fake), defaults: defaults)
        XCTAssertFalse(state.isKeepAwakeActive, "start() has not run yet")

        state.start()
        defer { state.stop() }

        XCTAssertTrue(state.isKeepAwakeActive)
    }

    func testStartDoesNotEnableWhenStartActiveSettingIsFalse() {
        let defaults = freshDefaults(#function)
        let state = AppState(defaults: defaults)

        state.start()
        defer { state.stop() }

        XCTAssertFalse(state.isKeepAwakeActive)
    }

    func testStopDisablesAnActiveAssertion() {
        let state = AppState(defaults: freshDefaults(#function))
        state.start()
        state.enableKeepAwake()
        XCTAssertTrue(state.isKeepAwakeActive)

        state.stop()

        XCTAssertFalse(state.isKeepAwakeActive)
    }
}
