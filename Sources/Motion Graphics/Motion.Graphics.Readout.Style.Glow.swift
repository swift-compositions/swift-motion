#if Graphics
    public import Motion

    extension Motion.Graphics.Readout.Style {
        /// The glow of the count and the bar: its deviation, and its strength at rest, added at full heat and
        /// added at a full flash.
        public struct Glow: Sendable, Hashable {
            public var deviation: Double
            public var rest: Double
            public var heat: Double
            public var flash: Double

            public init(deviation: Double, rest: Double, heat: Double, flash: Double) {
                self.deviation = deviation
                self.rest = rest
                self.heat = heat
                self.flash = flash
            }
        }
    }
#endif
