#if Graphics
    public import Motion

    extension Motion.Graphics.Title {
        /// A title's look: its ink, whose font, size and tracking set the line and whose colour a run without
        /// one takes, and the look of each run, taken in turn.
        public struct Style: Sendable {
            public var ink: Motion.Graphics.Ink

            public var runs: [Run]

            public init(ink: Motion.Graphics.Ink, runs: [Run]) {
                self.ink = ink
                self.runs = runs
            }
        }
    }
#endif
