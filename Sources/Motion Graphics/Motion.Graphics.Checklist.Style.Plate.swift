#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Checklist.Style {
        /// The plate: its surface and its corners, a coat over it that runs from one colour at its top to another at
        /// its foot, its edge's colour and pen, and the share of its size it grows by as it settles.
        public struct Plate: Sendable, Hashable {
            public var surface: Motion.Graphics.Surface
            public var corners: Motion.Graphics.Corners
            public var top: Picture.Color
            public var foot: Picture.Color
            public var edge: Picture.Color
            public var pen: Double
            public var settle: Double

            public init(
                surface: Motion.Graphics.Surface,
                corners: Motion.Graphics.Corners,
                top: Picture.Color,
                foot: Picture.Color,
                edge: Picture.Color,
                pen: Double,
                settle: Double
            ) {
                self.surface = surface
                self.corners = corners
                self.top = top
                self.foot = foot
                self.edge = edge
                self.pen = pen
                self.settle = settle
            }
        }
    }
#endif
