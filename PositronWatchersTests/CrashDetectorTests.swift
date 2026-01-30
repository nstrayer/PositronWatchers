import XCTest
@testable import PositronWatchers

final class CrashDetectorTests: XCTestCase {
    var detector: CrashDetector!

    override func setUp() {
        super.setUp()
        detector = CrashDetector()
    }

    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeProcess(pid: pid_t, name: String = "test") -> WatchedProcess {
        WatchedProcess(
            id: pid,
            name: name,
            commandLine: "/usr/bin/\(name)",
            workingDirectory: "/home/test",
            cpuPercent: 1.0,
            memoryMB: 50.0
        )
    }

    // MARK: - Initial State

    func testInitialStateEmpty() {
        XCTAssertTrue(detector.missingProcesses.isEmpty)
        XCTAssertFalse(detector.hasMissingProcesses)
        XCTAssertEqual(detector.missingCount, 0)
    }

    // MARK: - Process Tracking

    func testNoMissingWhenProcessesStable() {
        let processes = [makeProcess(pid: 100), makeProcess(pid: 200)]

        // First update establishes baseline
        _ = detector.update(currentProcesses: processes)
        XCTAssertFalse(detector.hasMissingProcesses)

        // Second update with same processes
        _ = detector.update(currentProcesses: processes)
        XCTAssertFalse(detector.hasMissingProcesses)
    }

    func testDetectsMissingProcess() {
        let initialProcesses = [
            makeProcess(pid: 100, name: "gulp-client"),
            makeProcess(pid: 200, name: "gulp-ext")
        ]

        // Establish baseline
        _ = detector.update(currentProcesses: initialProcesses)

        // Process 100 disappears
        let updatedProcesses = [makeProcess(pid: 200, name: "gulp-ext")]
        let missing = detector.update(currentProcesses: updatedProcesses)

        XCTAssertEqual(missing.count, 1)
        XCTAssertEqual(missing.first?.pid, 100)
        XCTAssertEqual(missing.first?.name, "gulp-client")
        XCTAssertTrue(detector.hasMissingProcesses)
        XCTAssertEqual(detector.missingCount, 1)
    }

    func testDetectsMultipleMissingProcesses() {
        let initialProcesses = [
            makeProcess(pid: 100),
            makeProcess(pid: 200),
            makeProcess(pid: 300)
        ]

        _ = detector.update(currentProcesses: initialProcesses)

        // All processes disappear
        let missing = detector.update(currentProcesses: [])

        XCTAssertEqual(missing.count, 3)
        XCTAssertEqual(detector.missingCount, 3)
    }

    func testNewProcessNotMarkedMissing() {
        let initialProcesses = [makeProcess(pid: 100)]
        _ = detector.update(currentProcesses: initialProcesses)

        // Add new process
        let updatedProcesses = [makeProcess(pid: 100), makeProcess(pid: 200)]
        let missing = detector.update(currentProcesses: updatedProcesses)

        XCTAssertTrue(missing.isEmpty)
        XCTAssertFalse(detector.hasMissingProcesses)
    }

    // MARK: - Acknowledgment

    func testAcknowledgeSingleProcess() {
        let processes = [makeProcess(pid: 100), makeProcess(pid: 200)]
        _ = detector.update(currentProcesses: processes)
        _ = detector.update(currentProcesses: [])

        XCTAssertEqual(detector.missingCount, 2)

        detector.acknowledge(pid: 100)
        XCTAssertEqual(detector.missingCount, 1)
        XCTAssertTrue(detector.hasMissingProcesses)

        detector.acknowledge(pid: 200)
        XCTAssertEqual(detector.missingCount, 0)
        XCTAssertFalse(detector.hasMissingProcesses)
    }

    func testAcknowledgeAll() {
        let processes = [makeProcess(pid: 100), makeProcess(pid: 200)]
        _ = detector.update(currentProcesses: processes)
        _ = detector.update(currentProcesses: [])

        XCTAssertEqual(detector.missingCount, 2)

        detector.acknowledgeAll()
        XCTAssertEqual(detector.missingCount, 0)
        XCTAssertFalse(detector.hasMissingProcesses)
    }

    func testAcknowledgeNonexistentPID() {
        let processes = [makeProcess(pid: 100)]
        _ = detector.update(currentProcesses: processes)
        _ = detector.update(currentProcesses: [])

        // Acknowledge a PID that was never missing
        detector.acknowledge(pid: 999)

        // Should still have the original missing process
        XCTAssertEqual(detector.missingCount, 1)
    }

    // MARK: - Missing Process Info

    func testMissingProcessContainsCorrectInfo() {
        let process = WatchedProcess(
            id: 12345,
            name: "gulp-watch",
            commandLine: "/usr/bin/node gulp watch-client",
            workingDirectory: "/home/user/project",
            cpuPercent: 5.5,
            memoryMB: 128.0
        )

        _ = detector.update(currentProcesses: [process])
        _ = detector.update(currentProcesses: [])

        guard let missing = detector.missingProcesses.first else {
            XCTFail("Expected missing process")
            return
        }

        XCTAssertEqual(missing.pid, 12345)
        XCTAssertEqual(missing.name, "gulp-watch")
        XCTAssertEqual(missing.commandLine, "/usr/bin/node gulp watch-client")
        XCTAssertEqual(missing.workingDirectory, "/home/user/project")
        XCTAssertNotNil(missing.detectedAt)
    }

    // MARK: - Accumulation

    func testMissingProcessesAccumulate() {
        // First cycle: process 100 starts
        _ = detector.update(currentProcesses: [makeProcess(pid: 100)])

        // Second cycle: process 100 disappears, 200 starts
        _ = detector.update(currentProcesses: [makeProcess(pid: 200)])
        XCTAssertEqual(detector.missingCount, 1)

        // Third cycle: process 200 disappears
        _ = detector.update(currentProcesses: [])
        XCTAssertEqual(detector.missingCount, 2)
    }
}
