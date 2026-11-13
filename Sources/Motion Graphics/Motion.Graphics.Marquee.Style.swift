#if Graphics
    public import Motion

    extension Motion.Graphics.Marquee {
        /// A marquee's look: the ink of its words, the faces its rows take in turn, the distance from one row's
        /// band to the next, and the gap between one copy of a row's words and the next.
        public struct Style: Sendable {
            public var ink: Motion.Graphics.Ink

            /// Row i takes the `i mod n`th of the n faces; with none, every row is filled.
            public var faces: [Face]
            public var pitch: Double
            public var gap: Double

            public init(ink: Motion.Graphics.Ink, faces: [Face], pitch: Double, gap: Double) {
                self.ink = ink
                self.faces = faces
                self.pitch = pitch
                self.gap = gap
            }
        }
    }
#endif
