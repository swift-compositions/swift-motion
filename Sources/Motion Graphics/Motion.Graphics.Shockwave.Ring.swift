#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Shockwave {
        /// One ring of a shockwave as it is drawn: its radius, its pen, the deviation of the Gaussian it is
        /// blurred by, 0 for a hard stroke, the share of its light it still has, 0 to 1, and its colour, which is
        /// faded by that share.
        public struct Ring: Sendable, Hashable {
            public var radius: Double
            public var pen: Double

            public var softness: Double
            public var light: Double
            public var color: Picture.Color

            public init(radius: Double, pen: Double, softness: Double = 0, light: Double, color: Picture.Color) {
                self.radius = radius
                self.pen = pen
                self.softness = softness
                self.light = light
                self.color = color
            }
        }
    }

    extension Motion.Graphics.Shockwave.Ring {
        /// How brightly the ring lights a thing at a distance from the wave's center: its light where the
        /// distance is its radius, falling evenly to nothing a pen to either side, so half its light at the
        /// pen's edge. A pen that is not positive lights nothing. The ring's softness is not counted: a soft
        /// ring lights a thing as the hard ring of its radius and pen does.
        public func light(at distance: Double) -> Double {
            guard pen > 0 else { return 0 }
            return light * Swift.max(0, 1 - Swift.abs(distance - radius) / pen)
        }
    }
#endif
