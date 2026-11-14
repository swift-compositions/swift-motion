#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Spinner.Style {
        /// The track under the arc, round the whole ring: its colour, clear for none, and its glow, which spares
        /// what the arc's spares and is drawn under the arc; nil for none.
        public struct Track: Sendable, Hashable {
            public var color: Picture.Color

            public var glow: Motion.Graphics.Glow?

            public init(color: Picture.Color, glow: Motion.Graphics.Glow? = nil) {
                self.color = color
                self.glow = glow
            }
        }
    }
#endif
