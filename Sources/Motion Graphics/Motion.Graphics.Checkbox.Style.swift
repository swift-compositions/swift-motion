#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Checkbox {
        /// A box's look: its half side, corner radius and the pen and colour of its edge; the fill's colour, the
        /// least half it is drawn at and its glow; how far beyond its size the box may spring; and the tick, a
        /// line through points about the centre, in its colour and weight.
        public struct Style: Sendable, Hashable {
            public var half: Double
            public var radius: Double
            public var pen: Double
            public var edge: Picture.Color
            public var fill: Picture.Color
            public var least: Double
            public var glow: Glow

            /// The largest share of its size the box springs to.
            public var overshoot: Double

            /// The tick's points, as offsets from the centre.
            public var tick: [Picture.Plane.Point<2>]
            public var mark: Picture.Color
            public var weight: Double

            public init(
                half: Double,
                radius: Double,
                pen: Double,
                edge: Picture.Color,
                fill: Picture.Color,
                least: Double,
                glow: Glow,
                overshoot: Double,
                tick: [Picture.Plane.Point<2>],
                mark: Picture.Color,
                weight: Double
            ) {
                self.half = half
                self.radius = radius
                self.pen = pen
                self.edge = edge
                self.fill = fill
                self.least = least
                self.glow = glow
                self.overshoot = overshoot
                self.tick = tick
                self.mark = mark
                self.weight = weight
            }
        }
    }
#endif
