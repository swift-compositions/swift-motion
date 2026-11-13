#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Shockwave {
        /// One ring of a shockwave as it is drawn: its radius, its pen and its colour.
        public struct Ring: Sendable, Hashable {
            public var radius: Double
            public var pen: Double
            public var color: Picture.Color

            public init(radius: Double, pen: Double, color: Picture.Color) {
                self.radius = radius
                self.pen = pen
                self.color = color
            }
        }
    }
#endif
