#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A brief star of light at a point: rays of light through the point and a glow at its core, which grow
        /// from nothing, shine and shrink back to nothing over the moment, turning as they go.
        public struct Twinkle: Sendable, Hashable {
            /// The star's center.
            public var place: Picture.Plane.Point<2>
            public var style: Style

            public init(at place: Picture.Plane.Point<2>, style: Style) {
                self.place = place
                self.style = style
            }
        }
    }
#endif
