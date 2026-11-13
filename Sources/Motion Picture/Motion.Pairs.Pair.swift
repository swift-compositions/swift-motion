#if Picture
    public import Motion

    extension Motion.Pairs {
        /// The frames two films show at one instant: the reference's and the other's, each nil where the film
        /// shows nothing then.
        public struct Pair: Sendable, Equatable {
            /// The instant, in seconds from each film's start.
            public var time: Rational

            /// The reference film's frame, set on the left.
            public var reference: Raster<Motion.Pixel>?

            /// The other film's frame, set on the right.
            public var other: Raster<Motion.Pixel>?

            public init(time: Rational, reference: Raster<Motion.Pixel>?, other: Raster<Motion.Pixel>?) {
                self.time = time
                self.reference = reference
                self.other = other
            }
        }
    }
#endif
