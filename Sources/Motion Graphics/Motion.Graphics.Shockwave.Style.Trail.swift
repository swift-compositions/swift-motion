#if Graphics
    public import Motion

    extension Motion.Graphics.Shockwave.Style {
        /// The echoes behind the lead ring: how many, how far behind each is, as a share of the spread, and what
        /// each keeps of the light of the ring before it.
        public struct Trail: Sendable, Hashable {
            public var count: Cardinal
            public var lag: Double
            public var fade: Double

            public init(count: Cardinal, lag: Double, fade: Double) {
                self.count = count
                self.lag = lag
                self.fade = fade
            }
        }
    }
#endif
