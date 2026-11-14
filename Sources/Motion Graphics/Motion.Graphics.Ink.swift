#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// How a run of text is set: a parsed font, a size in pixels (an em), a colour, and its tracking, the extra
        /// advance after every glyph as a share of the size, 0 by default.
        public struct Ink: Sendable {
            public var font: ISO_14496_22.FontFile

            public var size: Double

            public var color: Picture.Color

            public var tracking: Double

            public init(font: ISO_14496_22.FontFile, size: Double, color: Picture.Color, tracking: Double = 0) {
                self.font = font
                self.size = size
                self.color = color
                self.tracking = tracking
            }
        }
    }

    extension Motion.Graphics.Ink {
        /// A string set in this ink's font at its size and tracking.
        func text(_ string: Swift.String, size: Double? = nil, figures: Picture.Text.Figures = .proportional) throws(Picture.Text.Error) -> Picture.Text {
            try Picture.Text(string, font: font, size: size ?? self.size, tracking: tracking, figures: figures)
        }
    }
#endif
