import Motion_Clock_Lookup_Shims

extension Motion.Clock {
    /// The process's virtual clock as a clock of Swift's own, for code that sleeps: `now` is where the
    /// process's clock stands, and a sleep returns when `Motion.Clock` has been advanced to its deadline or
    /// past it, never by the wall clock.
    ///
    /// Hand it to code that takes `any Clock<Duration>` or a generic clock, such as a model that blinks a
    /// cursor, and that code then keeps step with the frames: every run wakes it at the same frames. Making
    /// one freezes nothing; until the process's clock is frozen it stands at zero, so a sleep begun before
    /// the freeze is measured from it. It needs the `Motion Clock Shims` library in the process from launch,
    /// as `Motion.Clock` does.
    public struct Stepped: _Concurrency::Clock, Sendable {
        /// A clock on the process's virtual time. Fails with `.absent` when the shim library is not in the
        /// process and with `.unhooked` when it was loaded after launch; it freezes nothing.
        public init() throws(Motion.Clock.Error) {
            switch motion_clock_lookup_state() {
            case 2: return
            case 1: throw .unhooked
            default: throw .absent
            }
        }
    }
}

extension Motion.Clock.Stepped {
    /// The sleeps of the one process clock, shared by every handle on it.
    static let sleepers = Sleepers()

    /// Where the process's clock stands: its `elapsed` since the freeze, zero before it.
    public var now: Instant {
        Instant(.nanoseconds(motion_clock_lookup_elapsed()))
    }

    /// One nanosecond, what the clock counts in.
    public var minimumResolution: Duration { .nanoseconds(1) }

    /// Suspends until the process's clock has been advanced to `deadline` or past it.
    ///
    /// A deadline the clock has already reached returns at once, without suspending. Otherwise the sleep
    /// holds no thread and waits for the advance that reaches its deadline; the wall clock never wakes it.
    /// The sleeps one advance reaches are resumed one after another, earliest deadline first and, for equal
    /// ones, in the order they began, each as the one before it resumes on its own actor: so the sleeps of
    /// one actor run in that order, each up to its next suspension before the next. A task cancelled before
    /// or while it sleeps throws `CancellationError` at once, the clock unmoved. The tolerance is not used.
    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws(CancellationError) {
        let isolation = #isolation
        if let actor = isolation {
            try await Self.sleepers.wait(until: deadline, on: actor)
        } else {
            try await Self.sleepers.wait(until: deadline)
        }
    }

    /// `sleep(until:tolerance:)` of `now` advanced by `duration`, on the caller's actor; a duration of zero
    /// or less returns at once.
    public func sleep(for duration: Duration, tolerance: Duration? = nil) async throws(CancellationError) {
        try await sleep(until: now.advanced(by: duration), tolerance: tolerance)
    }
}
