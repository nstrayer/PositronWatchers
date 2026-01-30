import Foundation

struct ProcessGroup: Identifiable {
    let id: String
    let workingDirectory: String
    var processes: [WatchedProcess]

    var shortWorkingDirectory: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if workingDirectory.hasPrefix(homeDir) {
            return "~" + workingDirectory.dropFirst(homeDir.count)
        }
        return workingDirectory
    }

    init(workingDirectory: String, processes: [WatchedProcess] = []) {
        self.id = workingDirectory
        self.workingDirectory = workingDirectory
        self.processes = processes
    }
}
