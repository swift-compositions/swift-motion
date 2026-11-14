#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A checklist on a frosted plate: a tracked heading that slides in, a statement that rises out of a slot,
        /// and rows of a box, a name and a tag, one row for each item on its layout's pitch. Its words are set
        /// once, when the checklist is made.
        public struct Checklist: Sendable {
            public let heading: Swift.String
            public let statement: Swift.String
            public let items: [Item]
            public let layout: Layout
            public let style: Style
            /// The rows: each item between the layout's left and right, the first on the first baseline and each
            /// next one a pitch lower.
            public let rows: [Row]
            /// The heading and the statement set in their inks.
            let headed: Picture.Text
            let stated: Picture.Text

            /// A checklist, its words set once: it fails as `Picture.Text` does for them in their inks.
            public init(heading: Swift.String, statement: Swift.String, items: [Item], layout: Layout, style: Style) throws(Picture.Text.Error) {
                self.heading = heading
                self.statement = statement
                self.items = items
                self.layout = layout
                self.style = style
                var rows: [Row] = []
                for (place, item) in items.enumerated() {
                    rows.append(try Row(item, left: layout.left, right: layout.right, baseline: layout.first + Double(place) * layout.pitch, style: style.row))
                }
                self.rows = rows
                let ink = style.heading.ink
                self.headed = try Picture.Text(heading, font: ink.font, size: ink.size, tracking: style.heading.tracking)
                self.stated = try style.statement.ink.text(statement)
            }
        }
    }
#endif
