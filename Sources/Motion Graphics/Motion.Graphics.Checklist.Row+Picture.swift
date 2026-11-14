#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A row at a moment: its box; its name `slide × (1 − named)` left of its place and faded by `named`; and
        /// the typed share of its tag, placed where the whole tag would end at the row's right edge.
        public init(_ row: Motion.Graphics.Checklist.Row, at moment: Motion.Graphics.Checklist.Row.Moment) throws(Picture.Text.Error) {
            guard moment.box.box > 0 else {
                self = .empty
                return
            }
            let style = row.style
            let box = row.checkbox
            var elements = Picture(box, at: moment.box).elements
            if moment.named > 0 {
                let name = try style.name.text(row.item.name)
                let point = Picture.Plane.Point<2>([box.centre[0] + style.gap - (1 - moment.named) * style.slide, row.baseline])
                elements.append(name.placed(.init(.solid(style.name.color.faded(by: Float(Swift.min(Swift.max(moment.named, 0), 1))))), at: point))
            }
            let count = row.item.tag.count
            let typed = Motion.Graphics.standing(moment.tagged, of: count)
            if typed > 0 {
                let whole = try style.tag.text(row.item.tag)
                let point = Picture.Plane.Point<2>([row.right - whole.width, row.baseline + style.drop])
                let shown = typed < count ? try style.tag.text(Swift.String(row.item.tag.prefix(typed))) : whole
                elements.append(shown.placed(.init(.solid(style.tag.color)), at: point))
            }
            self.init(elements)
        }
    }
#endif
