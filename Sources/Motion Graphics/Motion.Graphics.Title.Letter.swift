#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Title {
        /// One letter of a title at an instant: its glyph as the line sets it, the transform that puts it where it
        /// stands, its colour and its opacity. Its outline where it stands is the glyph's `path` under the
        /// transform, which is what a glint over the landed letters lights.
        public struct Letter: Sendable, Hashable {
            public var glyph: Typesetting.Glyph
            public var transform: Picture.Transform
            public var color: Picture.Color
            public var opacity: Double

            public init(glyph: Typesetting.Glyph, transform: Picture.Transform, color: Picture.Color, opacity: Double) {
                self.glyph = glyph
                self.transform = transform
                self.color = color
                self.opacity = opacity
            }
        }
    }

    extension Motion.Graphics.Title.Letter {
        /// The letter's outline where it stands.
        public var path: Picture.Plane.Path {
            Picture.Plane.Path(glyph.path).transformed(by: transform)
        }
    }
#endif
