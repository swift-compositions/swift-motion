#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A box to tick: a square outline with round corners about a center that springs in, a fill that grows
        /// from its middle and glows, flaring as it lands, and a tick drawn over it stroke by stroke.
        public struct Checkbox: Sendable, Hashable {
            /// The box's center.
            public var place: Picture.Plane.Point<2>
            public var style: Style

            public init(at place: Picture.Plane.Point<2>, style: Style) {
                self.place = place
                self.style = style
            }
        }
    }
#endif
