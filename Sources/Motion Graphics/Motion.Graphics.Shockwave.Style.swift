#if Graphics
    public import Motion
    public import Picture
    public import Timeline

    extension Motion.Graphics.Shockwave {
        /// A shockwave's look: the radius it sets out at, how much farther it reaches and the easing its reach
        /// follows, its pen as it sets out and as it ends, its colour as it sets out and as it ends, how fast its
        /// light falls, its trail of echoes and its glow.
        public struct Style: Sendable {
            public var radius: Double
            public var reach: Double

            /// How the reach follows a ring's spread: the ring stands `radius + reach × e(s)` out at a spread s,
            /// where e is this easing's progress over a duration of 1. Its pen and its light follow s itself.
            /// Linear by default.
            public var travel: Timeline.Easing<Double>

            public var pen: Double
            public var least: Double
            public var color: Picture.Color
            public var finish: Picture.Color

            /// The power of `1 − spread` the light falls by: 1 falls evenly, 2 falls fast and lingers faint.
            public var fall: Cardinal

            public var trail: Trail

            /// The glow of the rings; nil for none, so a caller that glows a whole picture the rings are part of
            /// does not glow them twice.
            public var glow: Motion.Graphics.Glow?

            public init(
                radius: Double,
                reach: Double,
                travel: Timeline.Easing<Double> = .linear,
                pen: Double,
                least: Double,
                color: Picture.Color,
                finish: Picture.Color,
                fall: Cardinal,
                trail: Trail,
                glow: Motion.Graphics.Glow?
            ) {
                self.radius = radius
                self.reach = reach
                self.travel = travel
                self.pen = pen
                self.least = least
                self.color = color
                self.finish = finish
                self.fall = fall
                self.trail = trail
                self.glow = glow
            }
        }
    }
#endif
