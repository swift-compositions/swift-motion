#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Title {
        /// A title's look: its font and size, and the look of each run, taken in turn.
        public struct Style: Sendable {
            public var font: ISO_14496_22.FontFile
            public var size: Double
            public var runs: [Run]

            public init(font: ISO_14496_22.FontFile, size: Double, runs: [Run]) {
                self.font = font
                self.size = size
                self.runs = runs
            }
        }
    }
#endif
