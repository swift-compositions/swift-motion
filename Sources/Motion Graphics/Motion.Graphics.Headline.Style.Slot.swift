#if Graphics
    public import Motion

    extension Motion.Graphics.Headline.Style {
        /// The window a line shows through: its top `above` sizes over the line's resting baseline, `height`
        /// sizes tall.
        public struct Slot: Sendable, Hashable {
            public var above: Double
            public var height: Double

            public init(above: Double, height: Double) {
                self.above = above
                self.height = height
            }
        }
    }
#endif
