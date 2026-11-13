#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A box to tick: a square outline with round corners about a centre that springs in, a fill that grows
        /// from its middle and glows, flaring as it lands, and a tick drawn over it stroke by stroke.
        public struct Checkbox: Sendable, Hashable {
            public var centre: Picture.Plane.Point<2>
            public var style: Style

            public init(at centre: Picture.Plane.Point<2>, style: Style) {
                self.centre = centre
                self.style = style
            }
        }
    }
#endif
