#if Graphics
    public import Motion

    extension Motion.Graphics.Caption.Style {
        /// The plate behind a caption: a rectangle from `ascent` above the first baseline to `descent` below the
        /// last, across the line's width, padded by `horizontal` and `vertical`, with its corners and made of its
        /// surface.
        public struct Plate: Sendable, Hashable {
            public var surface: Motion.Graphics.Surface
            public var corners: Motion.Graphics.Corners
            public var ascent: Double
            public var descent: Double
            public var horizontal: Double
            public var vertical: Double

            public init(
                surface: Motion.Graphics.Surface,
                corners: Motion.Graphics.Corners,
                ascent: Double,
                descent: Double,
                horizontal: Double,
                vertical: Double
            ) {
                self.surface = surface
                self.corners = corners
                self.ascent = ascent
                self.descent = descent
                self.horizontal = horizontal
                self.vertical = vertical
            }
        }
    }
#endif
