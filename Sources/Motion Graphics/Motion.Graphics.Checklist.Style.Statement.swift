#if Graphics
    public import Motion

    extension Motion.Graphics.Checklist.Style {
        /// The statement: its ink, how far right of the left edge it stands, how far below its baseline it starts
        /// its rise, and its slot, whose top is `above` over the baseline and which is `height` tall, across the
        /// plate.
        public struct Statement: Sendable {
            public var ink: Motion.Graphics.Ink
            public var indent: Double
            public var rise: Double
            public var above: Double
            public var height: Double

            public init(ink: Motion.Graphics.Ink, indent: Double, rise: Double, above: Double, height: Double) {
                self.ink = ink
                self.indent = indent
                self.rise = rise
                self.above = above
                self.height = height
            }
        }
    }
#endif
