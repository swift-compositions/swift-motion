#if Graphics
    public import Motion

    extension Motion.Graphics.Checklist.Row {
        /// A row's look: its box and how far the box's centre stands above the baseline; the name's ink, its gap
        /// from the box's centre and how far left of its place it starts its slide; the tag's ink and how far its
        /// baseline stands below the row's.
        public struct Style: Sendable {
            public var box: Motion.Graphics.Checkbox.Style
            public var rise: Double
            public var name: Motion.Graphics.Ink
            public var gap: Double
            public var slide: Double
            public var tag: Motion.Graphics.Ink
            public var drop: Double

            public init(
                box: Motion.Graphics.Checkbox.Style,
                rise: Double,
                name: Motion.Graphics.Ink,
                gap: Double,
                slide: Double,
                tag: Motion.Graphics.Ink,
                drop: Double
            ) {
                self.box = box
                self.rise = rise
                self.name = name
                self.gap = gap
                self.slide = slide
                self.tag = tag
                self.drop = drop
            }
        }
    }
#endif
