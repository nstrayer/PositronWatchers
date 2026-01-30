import Foundation

struct WatchedProcess: Identifiable, Hashable {
    let id: pid_t
    let name: String
    let commandLine: String
    let workingDirectory: String
    let cpuPercent: Double
    let memoryMB: Double

    var pid: pid_t { id }

    var displayName: String {
        // Extract meaningful name from command line
        // For gulp processes, show "gulp watch-client" style
        let components = commandLine.components(separatedBy: " ")
        if let gulpIndex = components.firstIndex(where: { $0.contains("gulp") }) {
            let relevant = components[gulpIndex...].prefix(3)
            return relevant.joined(separator: " ")
        }
        return name
    }
}
