#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A brief star of light at a point: rays of light through the point and a glow at its core, which grow
        /// from nothing, shine and shrink back to nothing over the moment, turning as they go.
        public struct Twinkle: Sendable, Hashable {
            public var centre: Picture.Plane.Point<2>
            public var style: Style

            public init(at centre: Picture.Plane.Point<2>, style: Style) {
                self.centre = centre
                self.style = style
            }
        }
    }
#endif
