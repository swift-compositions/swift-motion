#if Graphics
    public import Motion

    extension Motion.Graphics.Glint.Style {
        /// The glow of the lit band: its deviation and its strength.
        public struct Glow: Sendable, Hashable {
            public var deviation: Double
            public var strength: Double

            public init(deviation: Double, strength: Double) {
                self.deviation = deviation
                self.strength = strength
            }
        }
    }
#endif
