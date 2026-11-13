#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Window.Style {
        /// The traffic lights: discs in a row on the middle of the title bar, the first `inset` from the frame's
        /// left edge, each next one `step` further on.
        public struct Lights: Sendable, Hashable {
            public var count: Cardinal
            public var radius: Double
            public var inset: Double
            public var step: Double
            public var color: Picture.Color

            public init(count: Cardinal, radius: Double, inset: Double, step: Double, color: Picture.Color) {
                self.count = count
                self.radius = radius
                self.inset = inset
                self.step = step
                self.color = color
            }
        }
    }
#endif
