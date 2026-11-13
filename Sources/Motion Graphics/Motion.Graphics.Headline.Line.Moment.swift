#if Graphics
    public import Motion

    extension Motion.Graphics.Headline.Line {
        /// A line at an instant: how far it has risen into place, 0 to 1, and how far it has gone up out of its
        /// slot, 0 to 1.
        public struct Moment: Sendable, Hashable {
            public var risen: Double
            public var gone: Double

            public init(risen: Double, gone: Double = 0) {
                self.risen = risen
                self.gone = gone
            }
        }
    }

    extension Motion.Graphics.Headline.Line.Moment {
        /// Below its slot, not yet risen.
        public static let hidden = Self(risen: 0)

        /// In place.
        public static let resting = Self(risen: 1)
    }
#endif
