#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Checklist {
        /// One row of a checklist, which also stands alone: a box whose left edge is at `left` and whose center is
        /// the style's rise above the baseline, the item's name a gap right of the box's center, and its tag
        /// ending at `right`. The name and the tag are set once, when the row is made.
        public struct Row: Sendable {
            public let item: Item
            public var left: Double
            public var right: Double
            public var baseline: Double
            public let style: Style
            /// The name and the tag set in their inks.
            let name: Typesetting.Text
            let tag: Typesetting.Text
            /// Each of the tag's glyphs' outline where the tag sets it.
            let typed: [Picture.Plane.Path]

            /// A row, its name and tag set once: it fails as `Typesetting.Text` does for them in their inks.
            public init(_ item: Item, left: Double, right: Double, baseline: Double, style: Style) throws(Typesetting.Error) {
                self.item = item
                self.left = left
                self.right = right
                self.baseline = baseline
                self.style = style
                self.name = try style.name.text(item.name)
                self.tag = try style.tag.text(item.tag)
                self.typed = tag.glyphs.map { Picture.Plane.Path($0.path) }
            }
        }
    }

    extension Motion.Graphics.Checklist.Row {
        /// The row's box.
        public var checkbox: Motion.Graphics.Checkbox {
            Motion.Graphics.Checkbox(at: Picture.Plane.Point<2>([left + style.box.half, baseline - style.rise]), style: style.box)
        }
    }
#endif
