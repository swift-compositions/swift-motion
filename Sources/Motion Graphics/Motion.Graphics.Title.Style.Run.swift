#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Title.Style {
        /// How a run's letters look and enter: their colour; how far below its place a letter starts, in sizes,
        /// above it for a negative rise; how much larger than its size it starts, as a share of it; and how many
        /// times faster than it enters it comes up from clear.
        public struct Run: Sendable, Hashable {
            public var color: Picture.Color
            public var rise: Double
            public var grow: Double
            public var fade: Double

            public init(color: Picture.Color, rise: Double, grow: Double, fade: Double) {
                self.color = color
                self.rise = rise
                self.grow = grow
                self.fade = fade
            }
        }
    }
#endif
