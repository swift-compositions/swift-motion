#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Transcript.Style {
        /// The block caret: a rectangle in the cell after the last standing character, `left` and `right` in from
        /// the cell's sides, from `top` above the baseline to `bottom` below it, with round corners, glowing.
        public struct Caret: Sendable, Hashable {
            public var color: Picture.Color
            public var left: Double
            public var right: Double
            public var top: Double
            public var bottom: Double
            public var radius: Double

            /// The caret's glow; nil for none.
            public var glow: Motion.Graphics.Glow?

            public init(
                color: Picture.Color,
                left: Double,
                right: Double,
                top: Double,
                bottom: Double,
                radius: Double,
                glow: Motion.Graphics.Glow?
            ) {
                self.color = color
                self.left = left
                self.right = right
                self.top = top
                self.bottom = bottom
                self.radius = radius
                self.glow = glow
            }
        }
    }
#endif
