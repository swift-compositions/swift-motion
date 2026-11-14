#if Graphics
    public import Motion

    extension Motion.Graphics.Spinner {
        /// A spinner's look: the pen of its ring, the track round the whole ring and the arc over it, each with
        /// its colour and its glow.
        public struct Style: Sendable, Hashable {
            /// The ring's width, about its middle line.
            public var pen: Double

            public var track: Track

            public var arc: Arc

            public init(pen: Double, track: Track, arc: Arc) {
                self.pen = pen
                self.track = track
                self.arc = arc
            }
        }
    }
#endif
