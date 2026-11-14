#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Glint {
        /// A glint's look: its colour and its strength at the band's middle, 0 to 1; the band's width across; its
        /// slant from upright, in radians, clockwise on a screen; and its glow.
        public struct Style: Sendable, Hashable {
            public var color: Picture.Color
            public var strength: Double
            public var width: Double
            public var slant: Double
            /// The lit band's glow; nil for none.
            public var glow: Motion.Graphics.Glow?

            public init(color: Picture.Color, strength: Double, width: Double, slant: Double, glow: Motion.Graphics.Glow?) {
                self.color = color
                self.strength = strength
                self.width = width
                self.slant = slant
                self.glow = glow
            }
        }
    }
#endif
