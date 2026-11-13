#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Headline {
        /// A headline's look. Distances down are shares of the size the lines are set at, so they hold when the
        /// size shrinks to fit the measure.
        public struct Style: Sendable {
            public var font: ISO_14496_22.FontFile

            /// The largest size the lines are set at.
            public var size: Double

            /// The width the widest line is fitted to.
            public var measure: Double

            /// The distance from one baseline to the next, in sizes.
            public var pitch: Double

            /// How far below its place a line starts, and how far above it a line goes, in sizes.
            public var rise: Double

            public var slot: Slot

            /// The width of a line's slot, about the centre.
            public var span: Double

            /// The lines' colour, and their colour inside the region.
            public var ink: Picture.Color
            public var second: Picture.Color

            public init(
                font: ISO_14496_22.FontFile,
                size: Double,
                measure: Double,
                pitch: Double,
                rise: Double,
                slot: Slot,
                span: Double,
                ink: Picture.Color,
                second: Picture.Color
            ) {
                self.font = font
                self.size = size
                self.measure = measure
                self.pitch = pitch
                self.rise = rise
                self.slot = slot
                self.span = span
                self.ink = ink
                self.second = second
            }
        }
    }
#endif
