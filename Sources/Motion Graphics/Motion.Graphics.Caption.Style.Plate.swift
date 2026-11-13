#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Caption.Style {
        /// The plate behind a caption: a rectangle with round corners from `ascent` above the first baseline to
        /// `descent` below the last, across the line's width, padded by `horizontal` and `vertical`. Its colour's
        /// alpha is how much of what lies behind it the plate hides.
        public struct Plate: Sendable, Hashable {
            public var color: Picture.Color
            public var ascent: Double
            public var descent: Double
            public var horizontal: Double
            public var vertical: Double
            public var radius: Double

            public init(color: Picture.Color, ascent: Double, descent: Double, horizontal: Double, vertical: Double, radius: Double) {
                self.color = color
                self.ascent = ascent
                self.descent = descent
                self.horizontal = horizontal
                self.vertical = vertical
                self.radius = radius
            }
        }
    }
#endif
