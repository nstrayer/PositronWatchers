import Foundation

struct MissingProcess: Identifiable, Hashable {
    let id: pid_t
    let name: String
    let commandLine: String
    let workingDirectory: String
    let detectedAt: Date
    let exitReason: ProcessExitReason?

    var pid: pid_t { id }

    var crashSignalName: String {
        exitReason?.displayName ?? "unknown"
    }
}

final class CrashDetector {
    private(set) var missingProcesses: [MissingProcess] = []
    private var previousProcesses: [pid_t: WatchedProcess] = [:]

    /// Exit events received from kqueue between polls.
    private var kqueueExitedPIDs: [pid_t: ProcessExitReason] = [:]

    /// PIDs that have active kqueue watches.
    private var kqueueRegisteredPIDs: Set<pid_t> = []

    /// Called from ProcessExitMonitor callback (on main thread).
    /// If the exit reason is a crash, immediately creates a MissingProcess entry.
    func recordExit(pid: pid_t, reason: ProcessExitReason) {
        dispatchPrecondition(condition: .onQueue(.main))
        kqueueExitedPIDs[pid] = reason
        kqueueRegisteredPIDs.remove(pid)

        if reason.isCrash, let process = previousProcesses[pid] {
            let missing = MissingProcess(
                id: pid,
                name: process.name,
                commandLine: process.commandLine,
                workingDirectory: process.workingDirectory,
                detectedAt: Date(),
                exitReason: reason
            )
            missingProcesses.append(missing)
        }
    }

    /// Mark a PID as having an active kqueue watch.
    func markKqueueRegistered(pid: pid_t) {
        dispatchPrecondition(condition: .onQueue(.main))
        kqueueRegisteredPIDs.insert(pid)
    }

    /// Record that a PID exited before kqueue registration could complete.
    /// Prevents the poll-based fallback from treating it as an unknown disappearance.
    func recordUnobservedExit(pid: pid_t) {
        dispatchPrecondition(condition: .onQueue(.main))
        kqueueExitedPIDs[pid] = .unknown
    }

    func update(currentProcesses: [WatchedProcess]) -> [MissingProcess] {
        dispatchPrecondition(condition: .onQueue(.main))
        let currentPIDs = Set(currentProcesses.map(\.pid))
        var newlyMissing: [MissingProcess] = []

        // Find processes that were running but are now gone
        for (pid, process) in previousProcesses {
            if !currentPIDs.contains(pid) {
                // Check if kqueue already handled this PID
                if let reason = kqueueExitedPIDs[pid] {
                    // Already recorded in recordExit() if it was a crash -- skip
                    _ = reason
                } else if kqueueRegisteredPIDs.contains(pid) {
                    // kqueue watch is active but event hasn't arrived yet -- skip,
                    // the kqueue callback will handle it
                } else {
                    // No kqueue watch was registered for this PID (e.g., process exited
                    // before watch() was called, or ProcessExitMonitor failed to init).
                    // Without exit status we can't distinguish crashes from normal exits,
                    // so silently ignore rather than producing false positives.
                }
            }
        }

        // Update tracked processes
        previousProcesses.removeAll()
        for process in currentProcesses {
            previousProcesses[process.pid] = process
        }

        // Clean up stale kqueue tracking for PIDs no longer relevant
        let allKnownPIDs = Set(previousProcesses.keys)
            .union(missingProcesses.map(\.pid))
        kqueueExitedPIDs = kqueueExitedPIDs.filter { allKnownPIDs.contains($0.key) }
        kqueueRegisteredPIDs = kqueueRegisteredPIDs.intersection(allKnownPIDs)

        return newlyMissing
    }

    func acknowledge(pid: pid_t) {
        dispatchPrecondition(condition: .onQueue(.main))
        missingProcesses.removeAll { $0.pid == pid }
        kqueueExitedPIDs.removeValue(forKey: pid)
    }

    func acknowledgeAll() {
        dispatchPrecondition(condition: .onQueue(.main))
        missingProcesses.removeAll()
        kqueueExitedPIDs.removeAll()
    }

    var hasMissingProcesses: Bool {
        !missingProcesses.isEmpty
    }

    var missingCount: Int {
        missingProcesses.count
    }
}
