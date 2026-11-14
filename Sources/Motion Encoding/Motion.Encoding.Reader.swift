import Dispatch
import Motion

extension Motion.Encoding {
    /// The thread a movie is read on: a task executor that runs its jobs in order on a serial dispatch queue of
    /// its own. Such a queue is served outside Swift's cooperative pool, so a read that blocks its thread holds
    /// none of the pool's threads, and the queue's thread goes once the reader does.
    final class Reader: TaskExecutor {
        let queue = DispatchQueue(label: "Motion.Encoding.Reader")
    }
}

extension Motion.Encoding.Reader {
    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        queue.async { unsafe job.runSynchronously(on: self.asUnownedTaskExecutor()) }
    }
}
