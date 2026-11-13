#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Checklist.Style {
        /// The frosted plate: its corners' radius, the deviation of the blur it shows what is behind it through, a
        /// coat that runs from one colour at its top to another at its foot, its edge's colour and pen, and the
        /// share of its size it grows by as it settles.
        public struct Plate: Sendable, Hashable {
            public var radius: Double
            public var blur: Double
            public var top: Picture.Color
            public var foot: Picture.Color
            public var edge: Picture.Color
            public var pen: Double
            public var settle: Double

            public init(radius: Double, blur: Double, top: Picture.Color, foot: Picture.Color, edge: Picture.Color, pen: Double, settle: Double) {
                self.radius = radius
                self.blur = blur
                self.top = top
                self.foot = foot
                self.edge = edge
                self.pen = pen
                self.settle = settle
            }
        }
    }
#endif
