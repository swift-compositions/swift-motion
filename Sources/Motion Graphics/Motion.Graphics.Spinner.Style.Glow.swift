#if Graphics
    public import Motion

    extension Motion.Graphics.Spinner.Style {
        /// The arc's glow: its deviation, and its strength at rest and added at a full flash. It spares the
        /// inside of the ring, so the ring glows outward and its middle stays as dark as what is behind.
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
