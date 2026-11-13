#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Checklist.Style {
        /// The heading: its ink and tracking, the colour its ink turns to, and how far left of its place it starts
        /// its slide.
        public struct Heading: Sendable {
            public var ink: Motion.Graphics.Ink

            /// Extra advance after every glyph, as a share of the size.
            public var tracking: Double
            public var toned: Picture.Color
            public var slide: Double

            public init(ink: Motion.Graphics.Ink, tracking: Double, toned: Picture.Color, slide: Double) {
                self.ink = ink
                self.tracking = tracking
                self.toned = toned
                self.slide = slide
            }
        }
    }
#endif
