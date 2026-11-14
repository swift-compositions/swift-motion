extension Motion.Clock.Stepped.Sleepers {
    /// The sleeps, under the lock.
    struct State {
        var next: UInt64 = 0
        /// The sleeps no advance has reached.
        var waiting: [Sleeper] = []
        /// The sleeps advances have reached and not yet resumed, in the order they are resumed.
        var due: [Sleeper] = []
        /// Whether a resumed sleep has yet to resume the next.
        var waking = false
    }
}
