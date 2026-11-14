#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A glow: over what glows, a copy of it blurred by a Gaussian of `deviation`, adding its light at a
        /// strength, kept out of what a mask covers, as `Picture.glow(deviation:strength:sparing:)` draws it.
        ///
        /// `strength` is its strength at rest, and `flash` the strength a full flash adds, for a component whose
        /// moment flashes: at a flash of share f the strength is `strength + flash × f`. A glow of strength 0
        /// adds no light. A component without a glow, nil, draws none.
        public struct Glow: Sendable, Hashable {
            public var deviation: Double
            public var strength: Double
            public var flash: Double

            public init(deviation: Double, strength: Double, flash: Double = 0) {
                self.deviation = deviation
                self.strength = strength
                self.flash = flash
            }
        }
    }

    extension Motion.Graphics.Glow {
        /// The strength at a moment: the strength at rest, then what else the moment adds, such as a readout's
        /// heat, then the flash times its share, `strength + more + flash × share`.
        public func strength(flash share: Double, adding more: Double = 0) -> Double {
            strength + more + flash * share
        }

        /// A picture glowing at a strength, its light kept out of what a mask covers, as far as the mask's alpha
        /// goes: `picture.glow(deviation:strength:sparing:)` with this glow's deviation.
        public func applied(to picture: Picture, strength: Double, sparing mask: Picture = .empty) -> Picture {
            picture.glow(deviation: deviation, strength: Float(strength), sparing: mask)
        }

        /// A picture glowing at the strength at rest.
        public func applied(to picture: Picture, sparing mask: Picture = .empty) -> Picture {
            applied(to: picture, strength: strength, sparing: mask)
        }
    }
#endif
