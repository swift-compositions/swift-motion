import Dispatch
import Motion

extension Motion.Encoding {
    /// A thread of its own for work on AVFoundation: a serial dispatch queue, served outside Swift's cooperative
    /// pool, as the executor of a task and of an actor. A whole read, write, score or reduction runs on one, so
    /// what it does between its waits, and its resumption after each wait, needs no thread of the pool; and each
    /// `Wait.Held` object makes its calls on one of its own, so a call that blocks blocks that thread.
    ///
    /// It is a class that hands every job to its queue with `async`, never the queue itself as the executor: an
    /// actor whose executor is a `DispatchSerialQueue` was run by dispatch on the cooperative thread that called
    /// it, so a provider asked for its next sample there blocked a thread of the pool (stacks from a
    /// three-processor runner, macOS 27.2).
    ///
    /// An `AVAssetReader` output's provider waits for its next sample by blocking the thread that asks. Asked
    /// on the cooperative pool, as many readers as the pool has threads held all of it, and work they waited on
    /// that needed the pool never ran: on a three-processor Mac, three readers waited there for good while a
    /// writer's task had no thread to go on.
    final class Reader: SerialExecutor, TaskExecutor {
        let queue = DispatchSerialQueue(label: "Motion.Encoding.Reader")
    }
}

extension Motion.Encoding.Reader {
    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        queue.async {
            unsafe job.runSynchronously(isolatedTo: self.asUnownedSerialExecutor(), taskExecutor: self.asUnownedTaskExecutor())
        }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }
}

extension Motion.Encoding {
    /// `body` run on a `Reader` of its own.
    static func reading<T, Failure: Swift.Error>(_ body: () async throws(Failure) -> T) async throws(Failure) -> T {
        try await withTaskExecutorPreference(Reader(), operation: body)
    }
}
