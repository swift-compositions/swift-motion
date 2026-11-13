#if Graphics
    public import Motion

    extension Motion.Graphics.Headline {
        /// A headline at an instant: a moment for each line in order, a line without one hidden, and how far the
        /// block has opened from its first line alone to all its lines, 0 to 1.
        public struct Moment: Sendable, Hashable {
            public var lines: [Line.Moment]
            public var opened: Double

            public init(_ lines: [Line.Moment], opened: Double = 1) {
                self.lines = lines
                self.opened = opened
            }
        }
    }
#endif
