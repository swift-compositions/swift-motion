#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Spinner.Style {
        /// The arc that turns and fills: its colour, and its glow, its flash added at the moment's flash; nil for
        /// none.
        public struct Arc: Sendable, Hashable {
            public var color: Picture.Color

            public var glow: Motion.Graphics.Glow?

            public init(color: Picture.Color, glow: Motion.Graphics.Glow?) {
                self.color = color
                self.glow = glow
            }
        }
    }
#endif
