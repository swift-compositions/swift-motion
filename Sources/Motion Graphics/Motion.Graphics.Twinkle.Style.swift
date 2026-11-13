#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Twinkle {
        /// A twinkle's look: its rays and their colour, the colour of its core and the core's radius at full
        /// shine, and how far it turns over the whole twinkle, in radians.
        public struct Style: Sendable, Hashable {
            public var rays: [Ray]
            public var color: Picture.Color
            public var core: Picture.Color
            public var radius: Double
            public var turn: Double

            public init(rays: [Ray], color: Picture.Color, core: Picture.Color, radius: Double, turn: Double) {
                self.rays = rays
                self.color = color
                self.core = core
                self.radius = radius
                self.turn = turn
            }
        }
    }
#endif
