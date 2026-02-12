import Foundation

final class ServiceContainer {
    static let shared = ServiceContainer()

    let settingsStorage: SettingsStorage
    let processInfoFetcher: ProcessInfoFetcher
    let globMatcher: GlobMatcher
    let crashDetector: CrashDetector
    let processExitMonitor: ProcessExitMonitor?
    let processMonitor: ProcessMonitor

    private init() {
        settingsStorage = SettingsStorage()
        processInfoFetcher = ProcessInfoFetcher()
        globMatcher = GlobMatcher()
        crashDetector = CrashDetector()
        processExitMonitor = ProcessExitMonitor()
        processMonitor = ProcessMonitor(
            fetcher: processInfoFetcher,
            matcher: globMatcher,
            crashDetector: crashDetector,
            settings: settingsStorage,
            exitMonitor: processExitMonitor
        )
    }
}
