import Dispatch
import Motion

extension Motion.Hosting {
    /// One wait on the main queue. It ends once, at whichever comes first: its answer, its limit on the
    /// wall clock, or the cancellation of the task that waits.
    ///
    /// The hosts wait on things that may never answer: ScreenCaptureKit stops returning when several
    /// processes capture, and a wait measured on the machine's uptime never ends in a process whose
    /// clock is frozen. So every wait of theirs has a limit, and the limit is on the wall clock.
    @MainActor final class Wait<Answer> {
        var continuation: CheckedContinuation<Void, Never>?
        var answer: Answer?

        init() {}
    }
}

extension Motion.Hosting.Wait {
    func end() {
        continuation?.resume()
        continuation = nil
    }

    /// What `operation` gives, or nil when `limit` of wall time has passed or the waiting task was
    /// cancelled before it gave anything. The operation is not stopped: what it gives later is dropped.
    /// Without an operation this is a pause of `limit` that a cancellation cuts short.
    static func answer(within limit: Duration, of operation: (@MainActor () async -> Answer?)? = nil) async -> Answer? {
        let wait = Motion.Hosting.Wait<Answer>()
        if let operation {
            Task { @MainActor in
                wait.answer = await operation()
                wait.end()
            }
        }
        let (seconds, attoseconds) = limit.components
        let nanoseconds = Int(clamping: seconds) &* 1_000_000_000 &+ Int(attoseconds / 1_000_000_000)
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                wait.continuation = continuation
                DispatchQueue.main.asyncAfter(wallDeadline: .now() + .nanoseconds(nanoseconds)) { wait.end() }
            }
        } onCancel: {
            DispatchQueue.main.async { wait.end() }
        }
        return wait.answer
    }
}
