#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A row at a moment: its box; its name `slide × (1 − named)` left of its place and faded by `named`; and
        /// the typed share of its tag's glyphs, placed where the whole tag ends at the row's right edge.
        public init(_ row: Motion.Graphics.Checklist.Row, at moment: Motion.Graphics.Checklist.Row.Moment) {
            guard moment.box.box > 0 else {
                self = .empty
                return
            }
            let style = row.style
            let box = row.checkbox
            var elements = Picture(box, at: moment.box).elements
            if moment.named > 0 {
                let point = Picture.Plane.Point<2>([box.centre[0] + style.gap - (1 - moment.named) * style.slide, row.baseline])
                elements.append(row.name.placed(.init(.solid(style.name.color.faded(by: Float(Swift.min(Swift.max(moment.named, 0), 1))))), at: point))
            }
            let typed = Motion.Graphics.standing(moment.tagged, of: row.typed.count)
            if typed > 0 {
                let path = Picture.Plane.Path(subpaths: row.typed.prefix(typed).flatMap(\.subpaths))
                let move = Picture.Transform.translation(x: row.right - row.tag.width, y: row.baseline + style.drop)
                elements.append(.group(Picture.Group([.fill(path, .solid(style.tag.color))], transform: move)))
            }
            self.init(elements)
        }
    }
#endif
