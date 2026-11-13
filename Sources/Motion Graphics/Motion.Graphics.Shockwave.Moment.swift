#if Graphics
    public import Motion

    extension Motion.Graphics.Shockwave {
        /// A shockwave at an instant: how far it has spread, 0 as it sets out and 1 when it has gone, and below 0
        /// before it is thrown.
        public struct Moment: Sendable, Hashable {
            public var spread: Double

            public init(spread: Double) {
                self.spread = spread
            }
        }
    }

    extension Motion.Graphics.Shockwave.Moment {
        /// Not yet thrown.
        public static let hidden = Self(spread: -1)

        /// Gone by: a shockwave passes, and at rest nothing of it is left.
        public static let resting = Self(spread: 1)
    }
#endif
