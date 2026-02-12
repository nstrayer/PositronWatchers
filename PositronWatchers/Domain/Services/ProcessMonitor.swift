import Foundation
import Combine

final class ProcessMonitor: ObservableObject {
    @Published private(set) var processGroups: [ProcessGroup] = []
    @Published private(set) var projectPairCount: Int = 0
    @Published private(set) var hasCrashes: Bool = false

    private let fetcher: ProcessInfoFetcher
    private let matcher: GlobMatcher
    private let crashDetector: CrashDetector
    private let settings: SettingsStorage

    private var timer: Timer?
    private let pollingInterval: TimeInterval = 5.0

    init(fetcher: ProcessInfoFetcher, matcher: GlobMatcher, crashDetector: CrashDetector, settings: SettingsStorage) {
        self.fetcher = fetcher
        self.matcher = matcher
        self.crashDetector = crashDetector
        self.settings = settings
    }

    func startMonitoring() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        let allProcesses = fetcher.fetchAllProcesses()
        let patterns = settings.patterns

        // Filter processes matching any enabled pattern
        let matchedProcesses = allProcesses.filter { process in
            matcher.matchesAny(process.commandLine, patterns: patterns)
        }

        // Update crash detector
        _ = crashDetector.update(currentProcesses: matchedProcesses)
        hasCrashes = crashDetector.hasMissingProcesses

        // Group by working directory
        var groups: [String: [WatchedProcess]] = [:]
        for process in matchedProcesses {
            let cwd = process.workingDirectory.isEmpty ? "Unknown" : process.workingDirectory
            groups[cwd, default: []].append(process)
        }

        // Sort processes within each group by name
        processGroups = groups.map { cwd, processes in
            ProcessGroup(workingDirectory: cwd, processes: processes.sorted { $0.name < $1.name })
        }.sorted { $0.workingDirectory < $1.workingDirectory }

        // Project pair count = number of distinct working directories
        projectPairCount = processGroups.count
    }

    var missingProcesses: [MissingProcess] {
        crashDetector.missingProcesses
    }

    func acknowledgeCrash(pid: pid_t) {
        crashDetector.acknowledge(pid: pid)
        hasCrashes = crashDetector.hasMissingProcesses
    }

    func acknowledgeAllCrashes() {
        crashDetector.acknowledgeAll()
        hasCrashes = false
    }

    func killGroup(_ group: ProcessGroup) {
        let pids = Set(group.processes.map(\.pid))
        crashDetector.suppress(pids: pids)
        for pid in pids {
            kill(pid, SIGTERM)
        }
        poll()
    }
}
