#if Graphics
    public import Motion

    extension Motion.Graphics.Marquee.Style {
        /// The window a row shows through: from `above` sizes over the row's resting baseline down to `below`
        /// sizes under it.
        public struct Slot: Sendable, Hashable {
            public var above: Double
            public var below: Double

            public init(above: Double, below: Double) {
                self.above = above
                self.below = below
            }
        }
    }
#endif
