#if Graphics
    public import Motion

    extension Motion.Graphics.Checkbox.Style {
        /// The fill's glow: its deviation, and its strength at rest and added at a full flash.
        public struct Glow: Sendable, Hashable {
            public var deviation: Double
            public var rest: Double
            public var flash: Double

            public init(deviation: Double, rest: Double, flash: Double) {
                self.deviation = deviation
                self.rest = rest
                self.flash = flash
            }
        }
    }
#endif
