import Darwin
public import Motion

extension Motion {
    /// The process's virtual clock: once made, what this process reads as the machine's uptime stands still
    /// and moves only when this value moves it.
    ///
    /// It works through the `Motion Clock Shims` library, which must be in the process from launch: link
    /// that product into the executable. Making a second clock gives a second handle on the same one.
    public struct Clock: Sendable {
        let move: @convention(c) (UInt64) -> Void
        let read: @convention(c) () -> UInt64

        /// Freezes the process's clock. Fails with `.absent` when the shim library is not in the process,
        /// and with `.unhooked` when it is but was loaded after launch, so that time would run on unseen;
        /// in both cases nothing is frozen.
        public init() throws(Error) {
            let process = unsafe dlopen(nil, RTLD_NOW)
            guard
                let freeze = unsafe dlsym(process, "motion_clock_freeze").map({ unsafe unsafeBitCast($0, to: (@convention(c) () -> Void).self) }),
                let probe = unsafe dlsym(process, "motion_clock_probe").map({ unsafe unsafeBitCast($0, to: (@convention(c) () -> Void).self) }),
                let move = unsafe dlsym(process, "motion_clock_advance").map({ unsafe unsafeBitCast($0, to: (@convention(c) (UInt64) -> Void).self) }),
                let read = unsafe dlsym(process, "motion_clock_elapsed").map({ unsafe unsafeBitCast($0, to: (@convention(c) () -> UInt64).self) })
            else { throw .absent }
            probe()
            guard mach_absolute_time() == UInt64.max else { throw .unhooked }
            freeze()
            self.move = move
            self.read = read
        }
    }
}

extension Motion.Clock {
    /// How far the clock was moved on since it was frozen, in whole nanoseconds.
    public var elapsed: Duration { .nanoseconds(read()) }

    /// Moves the clock forward until `elapsed` is `instant`, cut to whole nanoseconds. Fails with
    /// `.backwards` for an instant before `elapsed` and with `.beyond` for one past what the clock can
    /// count, and then moves nothing.
    public func advance(to instant: Duration) throws(Error) {
        let (seconds, attoseconds) = instant.components
        let now = read()
        guard seconds >= 0, attoseconds >= 0 else { throw .backwards }
        let (whole, wide) = UInt64(seconds).multipliedReportingOverflow(by: 1_000_000_000)
        let (target, long) = whole.addingReportingOverflow(UInt64(attoseconds / 1_000_000_000))
        guard !wide, !long else { throw .beyond }
        guard target >= now else { throw .backwards }
        move(target - now)
    }

    /// Moves the clock forward to the start of `frame` at `rate`, counted from where it was frozen: the
    /// exact start, cut to whole nanoseconds, so no error builds up from frame to frame.
    public func advance(to frame: Ordinal, at rate: Rate) throws(Error) {
        try advance(to: try Self.start(of: frame, at: rate))
    }

    /// The start of `frame` at `rate`, cut to whole nanoseconds.
    public static func start(of frame: Ordinal, at rate: Rate) throws(Error) -> Duration {
        guard let index = Int(exactly: frame) else { throw .beyond }
        let nanoseconds = (rate.start(of: Integer(index)) * Rational(1_000_000_000 as Integer)).floor
        guard let whole = nanoseconds.exactly(Int64.self) else { throw .beyond }
        return .nanoseconds(whole)
    }
}
