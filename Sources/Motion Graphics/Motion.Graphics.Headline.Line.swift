#if Graphics
    public import Motion

    extension Motion.Graphics.Headline {
        /// One line of a headline: its words, and how far across it stands from the centre, so lines can drift
        /// apart.
        public struct Line: Sendable, Hashable {
            public var text: Swift.String
            public var offset: Double

            public init(_ text: Swift.String, offset: Double = 0) {
                self.text = text
                self.offset = offset
            }
        }
    }
#endif
