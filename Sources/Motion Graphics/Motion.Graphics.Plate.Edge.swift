#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Plate {
        /// A plate's edge: a line round its outline in a colour, a pen wide about the outline.
        public struct Edge: Sendable, Hashable {
            public var color: Picture.Color

            public var pen: Double

            public init(color: Picture.Color, pen: Double) {
                self.color = color
                self.pen = pen
            }
        }
    }
#endif
