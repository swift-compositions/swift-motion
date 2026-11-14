#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Spinner {
        /// A spinner's look: the pen of its ring, the colour of the track and of the arc, and the arc's glow.
        public struct Style: Sendable, Hashable {
            /// The ring's width, about its middle line.
            public var pen: Double

            /// The track under the arc, round the whole ring; clear for none.
            public var track: Picture.Color

            /// The arc's colour.
            public var ink: Picture.Color

            /// The arc's glow, its flash added at the moment's flash; nil for none.
            public var glow: Motion.Graphics.Glow?

            public init(pen: Double, track: Picture.Color, ink: Picture.Color, glow: Motion.Graphics.Glow?) {
                self.pen = pen
                self.track = track
                self.ink = ink
                self.glow = glow
            }
        }
    }
#endif
