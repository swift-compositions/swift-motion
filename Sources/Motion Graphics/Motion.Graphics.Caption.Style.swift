#if Graphics
    public import Motion

    extension Motion.Graphics.Caption {
        /// A caption's look: its line's transcript style, its plate, and how far below its place it starts its
        /// rise.
        public struct Style: Sendable {
            public var transcript: Motion.Graphics.Transcript.Style
            public var plate: Plate

            /// How far below its resting place the caption stands before it has risen.
            public var rise: Double

            public init(transcript: Motion.Graphics.Transcript.Style, plate: Plate, rise: Double) {
                self.transcript = transcript
                self.plate = plate
                self.rise = rise
            }
        }
    }
#endif
