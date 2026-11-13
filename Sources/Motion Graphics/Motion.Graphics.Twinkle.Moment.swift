#if Graphics
    public import Motion
    import Numeric

    extension Motion.Graphics.Twinkle {
        /// A twinkle at an instant: how far through its shine it is, 0 to 1.
        public struct Moment: Sendable, Hashable {
            public var shone: Double

            public init(shone: Double) {
                self.shone = shone
            }
        }
    }

    extension Motion.Graphics.Twinkle.Moment {
        /// Not yet shining.
        public static let hidden = Self(shone: 0)

        /// Shone and gone: a twinkle passes, and at rest nothing of it is left.
        public static let resting = Self(shone: 1)

        /// How bright the star is: `sin(π × shone)` while it shines, so 0 at its start and end and 1 halfway,
        /// and 0 outside them.
        public var shine: Double {
            guard shone > 0, shone < 1 else { return 0 }
            return Double.sin(Double.pi * shone)
        }
    }
#endif
