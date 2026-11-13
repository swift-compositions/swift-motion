#if Graphics
    public import Motion

    extension Motion.Graphics.Transcript {
        /// A transcript at an instant: a moment for each line in order. A line without one is hidden, though it
        /// keeps its rows.
        public struct Moment: Sendable, Hashable {
            public var lines: [Line.Moment]

            public init(_ lines: [Line.Moment]) {
                self.lines = lines
            }
        }
    }
#endif
