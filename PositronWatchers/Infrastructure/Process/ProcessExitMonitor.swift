import Foundation
import Darwin

// Swift's Darwin module imports both the `kevent` struct and the `kevent()` C function
// with the same name. Disambiguate by referencing the C symbol directly.
@_silgen_name("kevent")
private func sys_kevent(
    _ kq: Int32,
    _ changelist: UnsafePointer<kevent>?,
    _ nchanges: Int32,
    _ eventlist: UnsafeMutablePointer<kevent>?,
    _ nevents: Int32,
    _ timeout: UnsafePointer<timespec>?
) -> Int32

/// Monitors process exits using kqueue's EVFILT_PROC filter.
/// Provides the actual exit status/signal so we can distinguish crashes from normal termination.
final class ProcessExitMonitor {
    var onProcessExit: ((pid_t, ProcessExitReason) -> Void)?

    private let kqueueFD: Int32
    private let source: DispatchSourceRead
    private let lock = NSLock()
    private var watchedPIDs: Set<pid_t> = []

    init?() {
        let fd = Darwin.kqueue()
        guard fd >= 0 else { return nil }
        self.kqueueFD = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .utility))
        self.source = source

        source.setEventHandler { [weak self] in
            self?.drainEvents()
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        source.resume()
    }

    deinit {
        source.cancel()
    }

    /// Register a PID for exit monitoring. Returns false if the process already exited (ESRCH).
    func watch(pid: pid_t) -> Bool {
        var event = kevent(
            ident: UInt(pid),
            filter: Int16(EVFILT_PROC),
            flags: UInt16(EV_ADD | EV_ONESHOT),
            fflags: UInt32(NOTE_EXIT) | UInt32(bitPattern: NOTE_EXITSTATUS),
            data: 0,
            udata: nil
        )

        let result = sys_kevent(kqueueFD, &event, 1, nil, 0, nil)
        if result < 0 {
            // ESRCH means process already exited
            return false
        }

        lock.lock()
        watchedPIDs.insert(pid)
        lock.unlock()
        return true
    }

    func isWatching(pid: pid_t) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return watchedPIDs.contains(pid)
    }

    func unwatch(pid: pid_t) {
        var event = kevent(
            ident: UInt(pid),
            filter: Int16(EVFILT_PROC),
            flags: UInt16(EV_DELETE),
            fflags: 0,
            data: 0,
            udata: nil
        )
        // Ignore errors -- process may have already exited (EV_ONESHOT removed it)
        _ = sys_kevent(kqueueFD, &event, 1, nil, 0, nil)

        lock.lock()
        watchedPIDs.remove(pid)
        lock.unlock()
    }

    private func drainEvents() {
        var events = Array(repeating: kevent(), count: 16)
        var timeout = timespec(tv_sec: 0, tv_nsec: 0)

        while true {
            let count = sys_kevent(kqueueFD, nil, 0, &events, Int32(events.count), &timeout)
            guard count > 0 else { break }

            for i in 0..<Int(count) {
                let ev = events[i]
                let pid = pid_t(ev.ident)
                let reason = ProcessExitReason.from(status: ev.data)

                lock.lock()
                watchedPIDs.remove(pid)
                lock.unlock()

                let callback = self.onProcessExit
                DispatchQueue.main.async {
                    callback?(pid, reason)
                }
            }
        }
    }
}
