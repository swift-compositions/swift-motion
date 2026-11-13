#if Graphics
    public import Motion
    import Picture

    extension Motion.Graphics {
        /// A checklist on a frosted plate: a tracked heading that slides in, a statement that rises out of a slot,
        /// and rows of a box, a name and a tag, one row for each item on its layout's pitch.
        public struct Checklist: Sendable {
            public var heading: Swift.String
            public var statement: Swift.String
            public var items: [Item]
            public var layout: Layout
            public var style: Style

            public init(heading: Swift.String, statement: Swift.String, items: [Item], layout: Layout, style: Style) {
                self.heading = heading
                self.statement = statement
                self.items = items
                self.layout = layout
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Checklist {
        /// The rows: each item between the layout's left and right, the first on the first baseline and each next
        /// one a pitch lower.
        public var rows: [Row] {
            items.enumerated().map { place, item in
                Row(item, left: layout.left, right: layout.right, baseline: layout.first + Double(place) * layout.pitch, style: style.row)
            }
        }
    }
#endif
