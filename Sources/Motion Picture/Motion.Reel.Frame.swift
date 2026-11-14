#if Picture
    public import Motion

    extension Motion.Reel {
        /// A frame as a part or a layer is asked to draw it: its position, counted from zero at the start of the
        /// part or of the reel, and the instant at its center in seconds from that start.
        public struct Frame: Sendable, Hashable {
            public let position: Ordinal
            public let time: Rational

            public init(position: Ordinal, time: Rational) {
                self.position = position
                self.time = time
            }
        }
    }
#endif
