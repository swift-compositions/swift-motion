#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Spinner.Style {
        /// The arc's glow: its deviation, its strength at rest and added at a full flash, and what it spares.
        /// By default it spares the disc inside the ring, so the ring glows outward and its middle stays as dark
        /// as what is behind; a `mask` of the caller's, a picture in the spinner's space, spares what it covers
        /// instead, as far as its alpha goes, so the spared region can be soft.
        public struct Glow: Sendable, Hashable {
            public var deviation: Double
            public var rest: Double
            public var flash: Double
            public var mask: Picture?

            public init(deviation: Double, rest: Double, flash: Double, mask: Picture? = nil) {
                self.deviation = deviation
                self.rest = rest
                self.flash = flash
                self.mask = mask
            }
        }
    }
#endif
