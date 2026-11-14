import AVFoundation
import Dispatch
import Motion

extension Motion.Encoding {
    /// The waits on AVFoundation: for a load, for a reader's next sample, for a writer to take one, for an
    /// export to move on. AVFoundation may never answer one: a reader's next sample blocks its thread until the
    /// file's bytes come and a decoder answers. So every wait has a limit, on the wall clock as the hosts' waits
    /// do, and past it the work fails with `.unanswered`, naming what it waited for.
    enum Wait {
        /// How long AVFoundation has to answer one wait. A load, a sample or an export's step takes
        /// milliseconds; one that has not come by now is not coming.
        @TaskLocal static var limit: Duration = .seconds(10)

        /// The queue every limit's timer fires on: a serial queue of its own, which dispatch serves with a thread
        /// of its own however busy Swift's cooperative pool is.
        static let timers = DispatchQueue(label: "Motion.Encoding.Wait")
    }
}

extension Motion.Encoding.Wait {
    /// The wall-clock instant `limit` from now.
    static func deadline(after limit: Duration) -> DispatchWallTime {
        let (seconds, attoseconds) = limit.components
        return .now() + .nanoseconds(Int(clamping: seconds) &* 1_000_000_000 &+ Int(attoseconds / 1_000_000_000))
    }

    // swift-linter:disable:next untyped throws
    // REASON: the operations are AVFoundation's, which throw untyped; the public calls type them.
    /// What `operation` gives, or `.unanswered` with `what` once `limit` has passed on the wall clock.
    ///
    /// The operation runs as a task of its own on `executor`, a `Held` object's reader, so a call that blocks
    /// its thread blocks that one and the operation needs no thread of the pool. Past the limit the waiting caller goes on at once, `stop` is called, and the call that did not
    /// answer is left behind, not stopped: what it gives later is dropped. A limit of no time fails at once and
    /// starts nothing.
    static func answer<Answer: Sendable>(
        _ what: String,
        on executor: (any TaskExecutor)?,
        stop: (@Sendable () -> Void)? = nil,
        // swift-linter:disable:next untyped throws
        // REASON: the operations are AVFoundation's, which throw untyped.
        _ operation: @escaping @Sendable () async throws -> Answer
            // swift-linter:disable:next untyped throws
            // REASON: what the operation throws is passed on as it is; the public calls type it.
    ) async throws -> Answer {
        let limit = limit
        let late = Motion.Encoding.Error.unanswered("\(what) did not come within \(limit)")
        guard limit > .zero else {
            stop?()
            throw late
        }
        let ending = Ending<Answer>()
        let timer = DispatchWorkItem {
            if ending.end(with: .failure(late)) { stop?() }
        }
        defer { timer.cancel() }
        Task(executorPreference: executor) {
            // swift-linter:disable:next do throws for typed catch
            // REASON: the operation throws untyped; its error is passed on as it is.
            do {
                _ = ending.end(with: .success(try await operation()))
            } catch {
                _ = ending.end(with: .failure(error))
            }
        }
        timers.asyncAfter(wallDeadline: deadline(after: limit), execute: timer)
        return try await withCheckedThrowingContinuation { continuation in ending.begin(continuation) }
    }

    // swift-linter:disable:next untyped throws
    // REASON: AVFoundation's loaders throw untyped; the public calls type them.
    /// What a load gives, or `.unanswered` with `what` once `limit` has passed on the wall clock.
    ///
    /// A load waits without holding a thread, and `stop`, an asset's `cancelLoading()`, ends it at once with a
    /// cancellation, so it runs in place and is ended rather than left behind; a limit of no time stops it
    /// before it starts.
    static func load<Answer>(_ what: String, stop: @escaping @Sendable () -> Void, loading operation: () async throws -> Answer) async throws -> Answer {
        let limit = limit
        let late = Motion.Encoding.Error.unanswered("\(what) did not come within \(limit)")
        guard limit > .zero else {
            stop()
            throw late
        }
        let ending = Ending<Bool>()
        let timer = DispatchWorkItem {
            if ending.end(with: .success(false)) { stop() }
        }
        defer { timer.cancel() }
        timers.asyncAfter(wallDeadline: deadline(after: limit), execute: timer)
        // swift-linter:disable:next do throws for typed catch
        // REASON: the load throws untyped; its error is passed on as it is unless the limit ended it.
        do {
            let answer = try await operation()
            guard ending.end(with: .success(true)) else { throw late }
            return answer
        } catch {
            guard ending.end(with: .success(true)) else { throw late }
            throw error
        }
    }

    // swift-linter:disable:next untyped throws
    // REASON: the provider's next() throws untyped; the public calls type it.
    /// The next sample of a reader's output.
    static func sample(
        _ what: String,
        of samples: Held<Motion.Encoding.Samples>,
        stop: (@Sendable () -> Void)? = nil
            // swift-linter:disable:next untyped throws
            // REASON: the provider's next() throws untyped; the public calls type it.
    ) async throws -> CMReadySampleBuffer<CMSampleBuffer.DynamicContent>? {
        try await answer(what, on: samples.reader, stop: stop) { try await samples.next() }
    }

    // swift-linter:disable:next untyped throws
    // REASON: the export throws untyped; the public calls type it.
    /// An export to `url` as MP4. An export lasts as long as its movie needs, so what is waited for is the
    /// export moving on: once `limit` passes without a change in its state or progress, it is cancelled and
    /// fails with `.unanswered`.
    static func export(_ what: String, of session: sending AVAssetExportSession, to url: URL) async throws {
        let limit = limit
        let late = Motion.Encoding.Error.unanswered("\(what) did not move on within \(limit)")
        guard limit > .zero else { throw late }
        let states = session.states(updateInterval: 0.1)
        let ending = Ending<Void>()
        let exporting = Task(executorPreference: Motion.Encoding.Reader()) {
            // swift-linter:disable:next do throws for typed catch
            // REASON: the export throws untyped; its error is passed on as it is.
            do {
                try await session.export(to: url, as: .mp4)
                _ = ending.end(with: .success(()))
            } catch {
                _ = ending.end(with: .failure(error))
            }
        }
        let watching = Task(executorPreference: Motion.Encoding.Reader()) {
            var timer: DispatchWorkItem?
            var last: String?
            let arm = {
                timer?.cancel()
                let next = DispatchWorkItem {
                    if ending.end(with: .failure(late)) { exporting.cancel() }
                }
                timer = next
                timers.asyncAfter(wallDeadline: deadline(after: limit), execute: next)
            }
            arm()
            for await state in states {
                let now =
                    switch state {
                    case .pending: "pending"
                    case .waiting: "waiting"
                    case .exporting(let progress): "\(progress.completedUnitCount) of \(progress.totalUnitCount)"
                    @unknown default: "\(state)"
                    }
                guard now != last else { continue }
                last = now
                arm()
            }
            timer?.cancel()
        }
        defer { watching.cancel() }
        try await withCheckedThrowingContinuation { continuation in ending.begin(continuation) }
    }
}
