#if Graphics
    public import Motion
    import Picture

    extension Motion.Graphics.Checklist {
        /// One row of a checklist, which also stands alone: a box whose left edge is at `left` and whose centre is
        /// the style's rise above the baseline, the item's name a gap right of the box's centre, and its tag
        /// ending at `right`.
        public struct Row: Sendable {
            public var item: Item
            public var left: Double
            public var right: Double
            public var baseline: Double
            public var style: Style

            public init(_ item: Item, left: Double, right: Double, baseline: Double, style: Style) {
                self.item = item
                self.left = left
                self.right = right
                self.baseline = baseline
                self.style = style
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
