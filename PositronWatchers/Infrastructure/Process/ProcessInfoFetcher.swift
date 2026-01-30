import Foundation
import Darwin

final class ProcessInfoFetcher {
    func fetchAllProcesses() -> [WatchedProcess] {
        var processes: [WatchedProcess] = []
        let pids = getAllPIDs()

        for pid in pids {
            if let process = fetchProcessInfo(pid: pid) {
                processes.append(process)
            }
        }

        return processes
    }

    private func getAllPIDs() -> [pid_t] {
        var bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }

        // Add some buffer for new processes
        bufferSize += 100
        var pids = [pid_t](repeating: 0, count: Int(bufferSize))

        let actualCount = proc_listallpids(&pids, bufferSize * Int32(MemoryLayout<pid_t>.size))
        guard actualCount > 0 else { return [] }

        return Array(pids.prefix(Int(actualCount))).filter { $0 > 0 }
    }

    private func fetchProcessInfo(pid: pid_t) -> WatchedProcess? {
        guard let taskInfo = getTaskAllInfo(pid: pid) else { return nil }

        let commandLine = getCommandLine(pid: pid)
        // Skip processes with empty or unreadable command lines
        guard !commandLine.isEmpty else { return nil }

        let name = getProcessName(from: taskInfo)
        let cwd = getWorkingDirectory(pid: pid)
        let cpuPercent = calculateCPUPercent(taskInfo: taskInfo)
        let memoryMB = Double(taskInfo.ptinfo.pti_resident_size) / (1024.0 * 1024.0)

        return WatchedProcess(
            id: pid,
            name: name,
            commandLine: commandLine,
            workingDirectory: cwd,
            cpuPercent: cpuPercent,
            memoryMB: memoryMB
        )
    }

    private func getTaskAllInfo(pid: pid_t) -> proc_taskallinfo? {
        var info = proc_taskallinfo()
        let size = Int32(MemoryLayout<proc_taskallinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size)
        guard result == size else { return nil }
        return info
    }

    private func getProcessName(from info: proc_taskallinfo) -> String {
        withUnsafePointer(to: info.pbsd.pbi_name) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { cString in
                String(cString: cString)
            }
        }
    }

    private func getCommandLine(pid: pid_t) -> String {
        // Use sysctl to get command line arguments
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: Int = 0

        // First call to get the size
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else {
            return ""
        }

        // Allocate buffer
        var buffer = [UInt8](repeating: 0, count: size)

        // Second call to get the data
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else {
            return ""
        }

        // Parse KERN_PROCARGS2 format:
        // First 4 bytes: argc (number of arguments)
        // Then: executable path (null-terminated)
        // Then: arguments (null-separated)
        guard size > MemoryLayout<Int32>.size else { return "" }

        // Skip argc
        let startIndex = MemoryLayout<Int32>.size

        // Find null-separated strings
        var args: [String] = []
        var currentArg = ""
        var foundExePath = false
        var skippingNulls = false

        for i in startIndex..<size {
            let byte = buffer[i]
            if byte == 0 {
                if !currentArg.isEmpty {
                    if foundExePath {
                        args.append(currentArg)
                    } else {
                        foundExePath = true
                    }
                    currentArg = ""
                    skippingNulls = true
                }
            } else {
                if skippingNulls {
                    skippingNulls = false
                }
                currentArg.append(Character(UnicodeScalar(byte)))
            }

            // Limit number of args to prevent excessive memory usage
            if args.count >= 20 { break }
        }

        // Add final arg if present
        if !currentArg.isEmpty && foundExePath {
            args.append(currentArg)
        }

        return args.joined(separator: " ")
    }

    private func getWorkingDirectory(pid: pid_t) -> String {
        var pathInfo = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &pathInfo, size)
        guard result == size else { return "" }

        return withUnsafePointer(to: pathInfo.pvi_cdir.vip_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { cString in
                String(cString: cString)
            }
        }
    }

    private func calculateCPUPercent(taskInfo: proc_taskallinfo) -> Double {
        // This is a rough approximation
        // For accurate CPU %, you'd need to track deltas over time
        let userTime = Double(taskInfo.ptinfo.pti_total_user) / 1_000_000_000.0
        let systemTime = Double(taskInfo.ptinfo.pti_total_system) / 1_000_000_000.0
        let totalTime = userTime + systemTime

        // Just show accumulated CPU time as percentage indicator
        // In a real implementation, you'd calculate delta between polls
        return min(totalTime.truncatingRemainder(dividingBy: 100), 99.9)
    }
}
