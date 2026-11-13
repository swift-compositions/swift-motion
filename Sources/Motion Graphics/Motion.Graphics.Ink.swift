#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// How a run of text is set: a parsed font, a size in pixels (an em) and a colour.
        public struct Ink: Sendable {
            public var font: ISO_14496_22.FontFile
            public var size: Double
            public var color: Picture.Color

            public init(font: ISO_14496_22.FontFile, size: Double, color: Picture.Color) {
                self.font = font
                self.size = size
                self.color = color
            }
        }
    }

    extension Motion.Graphics.Ink {
        /// A string set in this ink's font at its size.
        func text(_ string: Swift.String, figures: Picture.Text.Figures = .proportional) throws(Picture.Text.Error) -> Picture.Text {
            try Picture.Text(string, font: font, size: size, figures: figures)
        }
    }
#endif
