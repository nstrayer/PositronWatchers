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

        // Process 100 disappears (no kqueue registered, so poll-based fallback)
        let updatedProcesses = [makeProcess(pid: 200, name: "gulp-ext")]
        let missing = detector.update(currentProcesses: updatedProcesses)

        XCTAssertEqual(missing.count, 1)
        XCTAssertEqual(missing.first?.pid, 100)
        XCTAssertEqual(missing.first?.name, "gulp-client")
        XCTAssertNil(missing.first?.exitReason)
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
        XCTAssertNil(missing.exitReason)
        XCTAssertEqual(missing.crashSignalName, "unknown")
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

    // MARK: - kqueue Exit Path

    func testRecordExitWithCrashSignalCreatesMissingProcess() {
        let processes = [makeProcess(pid: 100, name: "gulp-client")]
        _ = detector.update(currentProcesses: processes)

        // Simulate kqueue delivering SIGSEGV (signal 11)
        let reason = ProcessExitReason.signal(signal: 11, name: "SIGSEGV")
        detector.recordExit(pid: 100, reason: reason)

        XCTAssertEqual(detector.missingCount, 1)
        XCTAssertEqual(detector.missingProcesses.first?.exitReason, reason)
        XCTAssertEqual(detector.missingProcesses.first?.crashSignalName, "SIGSEGV")
        XCTAssertTrue(detector.hasMissingProcesses)
    }

    func testRecordExitWithSIGTERMDoesNotCreateMissingProcess() {
        let processes = [makeProcess(pid: 100, name: "gulp-client")]
        _ = detector.update(currentProcesses: processes)

        // Simulate kqueue delivering SIGTERM (signal 15)
        let reason = ProcessExitReason.signal(signal: 15, name: "SIGTERM")
        detector.recordExit(pid: 100, reason: reason)

        XCTAssertEqual(detector.missingCount, 0)
        XCTAssertFalse(detector.hasMissingProcesses)
    }

    func testRecordExitWithSIGKILLDoesNotCreateMissingProcess() {
        let processes = [makeProcess(pid: 100, name: "gulp-client")]
        _ = detector.update(currentProcesses: processes)

        // Simulate kqueue delivering SIGKILL (signal 9)
        let reason = ProcessExitReason.signal(signal: 9, name: "SIGKILL")
        detector.recordExit(pid: 100, reason: reason)

        XCTAssertEqual(detector.missingCount, 0)
        XCTAssertFalse(detector.hasMissingProcesses)
    }

    func testRecordExitWithNormalExitDoesNotCreateMissingProcess() {
        let processes = [makeProcess(pid: 100, name: "gulp-client")]
        _ = detector.update(currentProcesses: processes)

        // Simulate kqueue delivering normal exit(0)
        let reason = ProcessExitReason.normalExit(code: 0)
        detector.recordExit(pid: 100, reason: reason)

        XCTAssertEqual(detector.missingCount, 0)
        XCTAssertFalse(detector.hasMissingProcesses)
    }

    func testKqueueRegisteredPIDSkippedByPollFallback() {
        let processes = [makeProcess(pid: 100, name: "gulp-client")]
        _ = detector.update(currentProcesses: processes)

        // Mark PID as kqueue-registered (simulating successful watch() call)
        detector.markKqueueRegistered(pid: 100)

        // Process disappears from poll -- should NOT create missing process
        // because kqueue is watching it
        let missing = detector.update(currentProcesses: [])
        XCTAssertTrue(missing.isEmpty)
        XCTAssertEqual(detector.missingCount, 0)
    }

    func testKqueueExitedPIDNotDuplicatedByPoll() {
        let processes = [makeProcess(pid: 100, name: "gulp-client")]
        _ = detector.update(currentProcesses: processes)

        // kqueue delivers crash before poll runs
        let reason = ProcessExitReason.signal(signal: 11, name: "SIGSEGV")
        detector.recordExit(pid: 100, reason: reason)
        XCTAssertEqual(detector.missingCount, 1)

        // Poll now sees the process is gone -- should not duplicate
        let missing = detector.update(currentProcesses: [])
        XCTAssertTrue(missing.isEmpty)
        XCTAssertEqual(detector.missingCount, 1)
    }

    func testRecordExitWithSIGABRTCreatesMissingProcess() {
        let processes = [makeProcess(pid: 100, name: "gulp-client")]
        _ = detector.update(currentProcesses: processes)

        let reason = ProcessExitReason.signal(signal: 6, name: "SIGABRT")
        detector.recordExit(pid: 100, reason: reason)

        XCTAssertEqual(detector.missingCount, 1)
        XCTAssertEqual(detector.missingProcesses.first?.crashSignalName, "SIGABRT")
    }
}
