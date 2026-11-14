#if Graphics
    public import Motion

    extension Motion.Graphics.Headline.Line {
        /// A line at an instant: how far it has risen into place, 0 to 1, how far it has gone up out of its
        /// slot, 0 to 1, and how far it has drifted across from where it stands, in picture units, right for more.
        public struct Moment: Sendable, Hashable {
            public var risen: Double
            public var gone: Double
            public var drift: Double

            public init(risen: Double, gone: Double = 0, drift: Double = 0) {
                self.risen = risen
                self.gone = gone
                self.drift = drift
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
