import Motion
import Synchronization

extension Motion.Encoding.Wait {
    /// The one end of a wait: its answer or its limit, whichever comes first; the other is dropped. An end that
    /// comes before the waiter is kept for it.
    final class Ending<Answer: Sendable>: Sendable {
        let state: Mutex<(waiting: CheckedContinuation<Answer, any Swift.Error>?, ended: Result<Answer, any Swift.Error>?, done: Bool)>

        init() {
            self.state = Mutex((nil, nil, false))
        }
    }
}

extension Motion.Encoding.Wait.Ending {
    func begin(_ continuation: CheckedContinuation<Answer, any Swift.Error>) {
        let early = state.withLock { state in
            guard let ended = state.ended else {
                state.waiting = continuation
                return Result<Answer, any Swift.Error>?.none
            }
            state.ended = nil
            return ended
        }
        if let early { continuation.resume(with: early) }
    }

    /// Ends the wait with a result, true when this was its end and false when it had already ended.
    func end(with result: Result<Answer, any Swift.Error>) -> Bool {
        let (first, waiting) = state.withLock { state in
            guard !state.done else { return (false, CheckedContinuation<Answer, any Swift.Error>?.none) }
            state.done = true
            guard let waiting = state.waiting else {
                state.ended = result
                return (true, nil)
            }
            state.waiting = nil
            return (true, waiting)
        }
        waiting?.resume(with: result)
        return first
    }
}
