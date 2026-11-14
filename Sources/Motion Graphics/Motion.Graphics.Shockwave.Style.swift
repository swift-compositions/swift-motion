#if Graphics
    public import Motion
    public import Picture
    public import Timeline

    extension Motion.Graphics.Shockwave {
        /// A shockwave's look: the radius it sets out at, how much farther it reaches and the easing its reach
        /// follows, its pen, its softness and its colour as it sets out and as it ends, how its light falls, its
        /// trail of echoes and its glow.
        public struct Style: Sendable {
            public var radius: Double

            public var reach: Double

            /// How the reach follows a ring's spread: the ring stands `radius + reach × e(s)` out at a spread s,
            /// where e is this easing's progress over a duration of 1. Its pen, softness and colour follow s
            /// itself. Linear by default.
            public var travel: Timeline.Easing<Double>

            public var pen: Double

            public var least: Double

            /// The deviation of the Gaussian a ring is blurred by as it sets out, and as it ends: a ring at spread
            /// s is blurred by `soft + (softened − soft) × s`, as its pen goes from `pen` to `least`. 0 by
            /// default, a hard stroke.
            public var soft: Double

            public var softened: Double

            public var color: Picture.Color

            public var finish: Picture.Color

            /// How a ring's light falls as it spreads: its light at a spread s is this easing's progress at what is
            /// left of its spread, `f(1 − s)` over a duration of 1, so `.power(1)`, the default, falls evenly and
            /// `.power(2)` falls fast and lingers faint.
            public var fall: Timeline.Easing<Double>

            /// The echoes behind the lead ring; nil for none.
            public var trail: Trail?

            /// The glow of the rings; nil for none, so a caller that glows a whole picture the rings are part of
            /// does not glow them twice.
            public var glow: Motion.Graphics.Glow?

            public init(
                radius: Double,
                reach: Double,
                travel: Timeline.Easing<Double> = .linear,
                pen: Double,
                least: Double,
                soft: Double = 0,
                softened: Double = 0,
                color: Picture.Color,
                finish: Picture.Color,
                fall: Timeline.Easing<Double> = .power(1),
                trail: Trail? = nil,
                glow: Motion.Graphics.Glow?
            ) {
                self.radius = radius
                self.reach = reach
                self.travel = travel
                self.pen = pen
                self.least = least
                self.soft = soft
                self.softened = softened
                self.color = color
                self.finish = finish
                self.fall = fall
                self.trail = trail
                self.glow = glow
            }
        }
    }
#endif
