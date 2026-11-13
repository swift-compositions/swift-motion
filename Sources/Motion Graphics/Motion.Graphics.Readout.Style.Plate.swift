#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Readout.Style {
        /// The plate: its fill, whose alpha is how much of what lies behind it hides; its height, corner radius
        /// and the inset of the type from its sides; the type's baseline below its top; its edge's pen and the
        /// edge's alpha at rest and added at full heat; and the alpha of a full flash over it.
        public struct Plate: Sendable, Hashable {
            public var color: Picture.Color
            public var height: Double
            public var radius: Double
            public var inset: Double
            public var baseline: Double
            public var pen: Double
            public var edge: Double
            public var heat: Double
            public var flash: Double

            public init(
                color: Picture.Color,
                height: Double,
                radius: Double,
                inset: Double,
                baseline: Double,
                pen: Double,
                edge: Double,
                heat: Double,
                flash: Double
            ) {
                self.color = color
                self.height = height
                self.radius = radius
                self.inset = inset
                self.baseline = baseline
                self.pen = pen
                self.edge = edge
                self.heat = heat
                self.flash = flash
            }
        }
    }
#endif
