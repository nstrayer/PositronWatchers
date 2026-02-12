import Foundation

enum ProcessExitReason: Equatable, Hashable {
    case normalExit(code: Int32)
    case signal(signal: Int32, name: String)

    /// Decodes raw waitpid-style status (same encoding as kevent.data for NOTE_EXITSTATUS).
    /// The wait status only uses the low 16 bits (WIFEXITED/WIFSIGNALED macros mask with 0x7F
    /// and 0xFF), so truncating from Int (kevent.data is intptr_t) to Int32 is safe.
    static func from(status: Int) -> ProcessExitReason {
        let raw = Int32(status)
        // WIFEXITED: (status & 0x7F) == 0
        if (raw & 0x7F) == 0 {
            // WEXITSTATUS: (status >> 8) & 0xFF
            let exitCode = (raw >> 8) & 0xFF
            return .normalExit(code: exitCode)
        } else {
            // WTERMSIG: status & 0x7F
            let sig = raw & 0x7F
            return .signal(signal: sig, name: signalName(for: sig))
        }
    }

    /// True only for signals indicating a genuine crash.
    var isCrash: Bool {
        switch self {
        case .normalExit:
            return false
        case .signal(let sig, _):
            // SIGILL=4, SIGABRT=6, SIGFPE=8, SIGBUS=10, SIGSEGV=11
            return [4, 6, 8, 10, 11].contains(sig)
        }
    }

    var displayName: String {
        switch self {
        case .normalExit(let code):
            return "exit(\(code))"
        case .signal(_, let name):
            return name
        }
    }

    private static func signalName(for signal: Int32) -> String {
        switch signal {
        case 1: return "SIGHUP"
        case 2: return "SIGINT"
        case 3: return "SIGQUIT"
        case 4: return "SIGILL"
        case 5: return "SIGTRAP"
        case 6: return "SIGABRT"
        case 7: return "SIGEMT"
        case 8: return "SIGFPE"
        case 9: return "SIGKILL"
        case 10: return "SIGBUS"
        case 11: return "SIGSEGV"
        case 12: return "SIGSYS"
        case 13: return "SIGPIPE"
        case 14: return "SIGALRM"
        case 15: return "SIGTERM"
        default: return "SIG\(signal)"
        }
    }
}
