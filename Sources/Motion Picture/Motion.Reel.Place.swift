#if Picture
    public import Motion

    extension Motion.Reel {
        /// Where a frame of a reel falls: the place of its part in the reel's parts, that part's key, and the
        /// part's own frame.
        public struct Place: Sendable, Hashable {
            public let part: Ordinal
            public let key: Key
            public let frame: Ordinal

            public init(part: Ordinal, key: Key, frame: Ordinal) {
                self.part = part
                self.key = key
                self.frame = frame
            }
        }
    }
#endif
