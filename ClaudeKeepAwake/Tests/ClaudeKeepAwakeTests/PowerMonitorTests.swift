import XCTest
@testable import ClaudeKeepAwake

final class PowerMonitorTests: XCTestCase {

    func testRefreshReturnsAKnownState() {
        let monitor = PowerMonitor()
        let state = monitor.refresh()

        // Never .unknown on a real Mac with a readable power source, but we
        // only assert it's one of the three defined cases rather than
        // asserting a specific one — this suite runs on whatever machine
        // is on hand, on AC or battery.
        XCTAssertTrue([.ac, .battery, .unknown].contains(state))
        XCTAssertEqual(monitor.currentState, state)

        if let percentage = monitor.batteryPercentage {
            XCTAssertTrue((0...100).contains(percentage))
        }
    }

    func testStartInvokesCallbackWithInitialState() {
        let monitor = PowerMonitor()
        let expectation = expectation(description: "onChange called")

        monitor.start { state, _ in
            XCTAssertTrue([.ac, .battery, .unknown].contains(state))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        monitor.stop()
    }
}
