#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Shockwave {
        /// A shockwave's look: the radius it sets out at and how much farther it reaches, its pen as it sets out
        /// and as it ends, its colour as it sets out and as it ends, how fast its light falls, its trail of echoes
        /// and its glow.
        public struct Style: Sendable, Hashable {
            public var radius: Double
            public var reach: Double
            public var pen: Double
            public var least: Double
            public var color: Picture.Color
            public var finish: Picture.Color

            /// The power of `1 − spread` the light falls by: 1 falls evenly, 2 falls fast and lingers faint.
            public var fall: Cardinal

            public var trail: Trail

            /// The glow of the rings: its deviation and strength.
            public var deviation: Double
            public var strength: Double

            public init(
                radius: Double,
                reach: Double,
                pen: Double,
                least: Double,
                color: Picture.Color,
                finish: Picture.Color,
                fall: Cardinal,
                trail: Trail,
                deviation: Double,
                strength: Double
            ) {
                self.radius = radius
                self.reach = reach
                self.pen = pen
                self.least = least
                self.color = color
                self.finish = finish
                self.fall = fall
                self.trail = trail
                self.deviation = deviation
                self.strength = strength
            }
        }
    }
#endif
