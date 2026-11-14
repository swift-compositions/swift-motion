#if Graphics
    public import Motion

    extension Motion.Graphics {
        /// The window a line of type shows through as it rises into place or leaves: from `above` sizes over the
        /// line's resting baseline down to `below` sizes under it, a size being the size the line is set at.
        public struct Slot: Sendable, Hashable {
            public var above: Double

            public var below: Double

            public init(above: Double, below: Double) {
                self.above = above
                self.below = below
            }
        }
    }

    extension Motion.Graphics.Slot {
        /// The slot's top and bottom about a resting baseline for a line set at a size.
        public func span(baseline: Double, size: Double) -> (top: Double, bottom: Double) {
            (baseline - above * size, baseline + below * size)
        }
    }
#endif
