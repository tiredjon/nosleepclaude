import XCTest
@testable import ClaudeKeepAwake

/// Deliberately does NOT call enable()/disable() here: that would register
/// a real login item pointing at the test binary in the user's System
/// Settings, which is a real, user-visible side effect a test suite must
/// not cause. Registration is exercised manually — see context/TESTING.md.
final class LaunchAtLoginManagerTests: XCTestCase {

    func testStatusQueryDoesNotCrashAndIsAKnownCase() {
        let manager = LaunchAtLoginManager()
        let status = manager.status
        XCTAssertTrue(
            [.notRegistered, .enabled, .requiresApproval, .notFound, .unknown].contains(status)
        )
    }

    func testIsEnabledReflectsStatus() {
        let manager = LaunchAtLoginManager()
        let expected = manager.status == .enabled || manager.status == .requiresApproval
        XCTAssertEqual(manager.isEnabled, expected)
    }
}
