#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Checklist.Style {
        /// The heading: its ink, its tracking among it, the colour its ink turns to, and how far left of its place
        /// it starts its slide.
        public struct Heading: Sendable {
            public var ink: Motion.Graphics.Ink

            public var toned: Picture.Color

            public var slide: Double

            public init(ink: Motion.Graphics.Ink, toned: Picture.Color, slide: Double) {
                self.ink = ink
                self.toned = toned
                self.slide = slide
            }
        }
    }
#endif
