#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Headline {
        /// A headline's look. Distances down are shares of the size the lines are set at, so they hold when the
        /// size shrinks to fit the measure.
        public struct Style: Sendable {
            /// The lines' font, the largest size they are set at, their colour and their tracking.
            public var ink: Motion.Graphics.Ink

            /// The lines' colour inside the region.
            public var second: Picture.Color

            /// The width the widest line is fitted to.
            public var measure: Double

            /// The distance from one baseline to the next, in sizes.
            public var pitch: Double

            /// How far below its place a line starts, and how far above it a line goes, in sizes.
            public var rise: Double

            public var slot: Motion.Graphics.Slot

            /// The width of a line's slot, about the centre.
            public var span: Double

            public init(
                ink: Motion.Graphics.Ink,
                second: Picture.Color,
                measure: Double,
                pitch: Double,
                rise: Double,
                slot: Motion.Graphics.Slot,
                span: Double
            ) {
                self.ink = ink
                self.second = second
                self.measure = measure
                self.pitch = pitch
                self.rise = rise
                self.slot = slot
                self.span = span
            }
        }
    }
#endif
