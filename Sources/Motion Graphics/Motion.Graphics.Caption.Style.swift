#if Graphics
    public import Motion

    extension Motion.Graphics.Caption {
        /// A caption's look: its line's transcript style; its plate, a rectangle from `ascent` above the first
        /// baseline to `descent` below the last, across the line's width, padded by `horizontal` and `vertical`;
        /// and how far below its place it starts its rise.
        public struct Style: Sendable {
            public var transcript: Motion.Graphics.Transcript.Style

            public var plate: Motion.Graphics.Plate

            public var ascent: Double

            public var descent: Double

            public var horizontal: Double

            public var vertical: Double

            /// How far below its resting place the caption stands before it has risen.
            public var rise: Double

            public init(
                transcript: Motion.Graphics.Transcript.Style,
                plate: Motion.Graphics.Plate,
                ascent: Double,
                descent: Double,
                horizontal: Double,
                vertical: Double,
                rise: Double
            ) {
                self.transcript = transcript
                self.plate = plate
                self.ascent = ascent
                self.descent = descent
                self.horizontal = horizontal
                self.vertical = vertical
                self.rise = rise
            }
        }
    }
#endif
