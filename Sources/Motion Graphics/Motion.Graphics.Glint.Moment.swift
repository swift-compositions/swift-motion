#if Graphics
    public import Motion

    extension Motion.Graphics.Glint {
        /// A glint at an instant: how far it has swept across the shape, 0 before it to 1 past it, and how much of
        /// its light is on, 0 to 1.
        public struct Moment: Sendable, Hashable {
            public var swept: Double
            public var light: Double

            public init(swept: Double, light: Double = 1) {
                self.swept = swept
                self.light = light
            }
        }
    }

    extension Motion.Graphics.Glint.Moment {
        /// Not yet come: the band is before the shape.
        public static let hidden = Self(swept: 0)

        /// Gone by: a glint passes, and at rest nothing of it is left.
        public static let resting = Self(swept: 1)
    }
#endif
