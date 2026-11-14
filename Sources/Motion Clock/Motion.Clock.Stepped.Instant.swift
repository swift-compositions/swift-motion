extension Motion.Clock.Stepped {
    /// An instant on the process's virtual clock: how far it stands from the freeze.
    public struct Instant: InstantProtocol, Sendable, Hashable {
        /// The time from the freeze, in whole nanoseconds when the clock reads it.
        public var elapsed: Duration

        public init(_ elapsed: Duration) {
            self.elapsed = elapsed
        }
    }
}

extension Motion.Clock.Stepped.Instant {
    public func advanced(by duration: Duration) -> Self {
        Self(elapsed + duration)
    }

    public func duration(to other: Self) -> Duration {
        other.elapsed - elapsed
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.elapsed < rhs.elapsed
    }
}
