import XCTest
import IOKit.pwr_mgt
@testable import ClaudeKeepAwake

/// A fake `IOPMAssertionProviding` that behaves like a tiny in-memory
/// powerd, letting us test success AND failure paths deterministically
/// without touching real hardware assertions for the failure cases.
final class FakeAssertionProvider: IOPMAssertionProviding {
    var nextCreateResult: IOReturn = kIOReturnSuccess
    var nextReleaseResult: IOReturn = kIOReturnSuccess
    var createCallCount = 0
    var releaseCallCount = 0
    var existingIDs: Set<IOPMAssertionID> = []
    private var nextID: IOPMAssertionID = 1

    func createAssertion(name: String) -> (result: IOReturn, id: IOPMAssertionID) {
        createCallCount += 1
        guard nextCreateResult == kIOReturnSuccess else {
            return (nextCreateResult, IOPMAssertionID(kIOPMNullAssertionID))
        }
        let id = nextID
        nextID += 1
        existingIDs.insert(id)
        return (kIOReturnSuccess, id)
    }

    func releaseAssertion(_ id: IOPMAssertionID) -> IOReturn {
        releaseCallCount += 1
        guard nextReleaseResult == kIOReturnSuccess else {
            return nextReleaseResult
        }
        existingIDs.remove(id)
        return kIOReturnSuccess
    }

    func assertionExists(_ id: IOPMAssertionID) -> Bool {
        existingIDs.contains(id)
    }
}

final class SleepManagerTests: XCTestCase {

    // MARK: - Real IOKit success path

    func testRealEnableThenDisableSucceeds() throws {
        let manager = SleepManager()
        XCTAssertFalse(manager.isActive)

        try manager.enable()
        XCTAssertTrue(manager.isActive)

        try manager.disable()
        XCTAssertFalse(manager.isActive)
    }

    func testRealRepeatedEnableDisableDoesNotLeakOrThrow() throws {
        let manager = SleepManager()
        for _ in 0..<5 {
            try manager.enable()
            XCTAssertTrue(manager.isActive)
            try manager.disable()
            XCTAssertFalse(manager.isActive)
        }
    }

    func testRealDoubleEnableThrowsAlreadyActive() throws {
        let manager = SleepManager()
        try manager.enable()
        defer { try? manager.disable() }

        XCTAssertThrowsError(try manager.enable()) { error in
            XCTAssertEqual(error as? SleepManagerError, .alreadyActive)
        }
    }

    func testRealDisableWithoutEnableThrowsNotActive() {
        let manager = SleepManager()
        XCTAssertThrowsError(try manager.disable()) { error in
            XCTAssertEqual(error as? SleepManagerError, .notActive)
        }
    }

    func testRealVerifyAfterWakeIsANoOpWhenAssertionStillValid() throws {
        let manager = SleepManager()
        try manager.enable()
        defer { try? manager.disable() }

        let recreated = manager.verifyAfterWake()
        XCTAssertFalse(recreated)
        XCTAssertTrue(manager.isActive)
    }

    func testRealVerifyAfterWakeWhenInactiveIsANoOp() {
        let manager = SleepManager()
        XCTAssertFalse(manager.verifyAfterWake())
        XCTAssertFalse(manager.isActive)
    }

    // MARK: - Fake provider: failure paths a real device won't reliably reproduce

    func testFakeAssertionCreationFailureSurfacesError() {
        let fake = FakeAssertionProvider()
        fake.nextCreateResult = kIOReturnError
        let manager = SleepManager(provider: fake)

        XCTAssertThrowsError(try manager.enable()) { error in
            XCTAssertEqual(error as? SleepManagerError, .assertionCreationFailed(kIOReturnError))
        }
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(fake.createCallCount, 1)
    }

    func testFakeAssertionReleaseFailureSurfacesErrorAndKeepsActiveTrue() throws {
        let fake = FakeAssertionProvider()
        let manager = SleepManager(provider: fake)
        try manager.enable()

        fake.nextReleaseResult = kIOReturnError
        XCTAssertThrowsError(try manager.disable()) { error in
            XCTAssertEqual(error as? SleepManagerError, .assertionReleaseFailed(kIOReturnError))
        }
        // A failed release must not silently mark us inactive — that would
        // leak the assertion (still held by powerd) with no way to release it.
        XCTAssertTrue(manager.isActive)
    }

    func testFakeVerifyAfterWakeRecreatesMissingAssertionWithoutDuplicating() throws {
        let fake = FakeAssertionProvider()
        let manager = SleepManager(provider: fake)
        try manager.enable()
        XCTAssertEqual(fake.createCallCount, 1)

        // Simulate powerd having lost the assertion across sleep/wake.
        fake.existingIDs.removeAll()

        let recreated = manager.verifyAfterWake()
        XCTAssertTrue(recreated)
        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(fake.createCallCount, 2, "exactly one recreation, no duplicate assertions")
    }

    func testFakeVerifyAfterWakeRecreationFailureLeavesInactive() throws {
        let fake = FakeAssertionProvider()
        let manager = SleepManager(provider: fake)
        try manager.enable()

        fake.existingIDs.removeAll()
        fake.nextCreateResult = kIOReturnError

        let recreated = manager.verifyAfterWake()
        XCTAssertTrue(recreated, "an attempt was made")
        XCTAssertFalse(manager.isActive, "failed recreation must not report ACTIVE")
    }

    func testFakeDeinitReleasesAssertionToAvoidLeak() {
        let fake = FakeAssertionProvider()
        var manager: SleepManager? = SleepManager(provider: fake)
        _ = try? manager!.enable()
        XCTAssertEqual(fake.existingIDs.count, 1)

        manager = nil

        XCTAssertEqual(fake.releaseCallCount, 1)
        XCTAssertTrue(fake.existingIDs.isEmpty)
    }
}
