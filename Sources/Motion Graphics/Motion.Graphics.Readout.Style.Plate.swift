#if Graphics
    public import Motion

    extension Motion.Graphics.Readout.Style {
        /// The plate: its surface and its corners; its height and the inset of the type from its sides; the type's baseline below its top; its edge's pen and the
        /// edge's alpha at rest and added at full heat; and the alpha of a full flash over it.
        public struct Plate: Sendable, Hashable {
            public var surface: Motion.Graphics.Surface
            public var corners: Motion.Graphics.Corners
            public var height: Double
            public var inset: Double
            public var baseline: Double
            public var pen: Double
            public var edge: Double
            public var heat: Double
            public var flash: Double

            public init(
                surface: Motion.Graphics.Surface,
                corners: Motion.Graphics.Corners,
                height: Double,
                inset: Double,
                baseline: Double,
                pen: Double,
                edge: Double,
                heat: Double,
                flash: Double
            ) {
                self.surface = surface
                self.corners = corners
                self.height = height
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
