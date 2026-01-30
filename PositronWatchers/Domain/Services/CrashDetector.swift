import Foundation

struct MissingProcess: Identifiable, Hashable {
    let id: pid_t
    let name: String
    let commandLine: String
    let workingDirectory: String
    let detectedAt: Date

    var pid: pid_t { id }
}

final class CrashDetector {
    private(set) var missingProcesses: [MissingProcess] = []
    private var previousProcesses: [pid_t: WatchedProcess] = [:]

    func update(currentProcesses: [WatchedProcess]) -> [MissingProcess] {
        let currentPIDs = Set(currentProcesses.map(\.pid))
        var newlyMissing: [MissingProcess] = []

        // Find processes that were running but are now gone
        for (pid, process) in previousProcesses {
            if !currentPIDs.contains(pid) {
                let missing = MissingProcess(
                    id: pid,
                    name: process.name,
                    commandLine: process.commandLine,
                    workingDirectory: process.workingDirectory,
                    detectedAt: Date()
                )
                missingProcesses.append(missing)
                newlyMissing.append(missing)
            }
        }

        // Update tracked processes
        previousProcesses.removeAll()
        for process in currentProcesses {
            previousProcesses[process.pid] = process
        }

        return newlyMissing
    }

    func acknowledge(pid: pid_t) {
        missingProcesses.removeAll { $0.pid == pid }
    }

    func acknowledgeAll() {
        missingProcesses.removeAll()
    }

    var hasMissingProcesses: Bool {
        !missingProcesses.isEmpty
    }

    var missingCount: Int {
        missingProcesses.count
    }
}
