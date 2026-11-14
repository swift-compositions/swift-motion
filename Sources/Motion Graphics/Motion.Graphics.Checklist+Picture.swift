#if Graphics
    import Standard_Library_Extensions
    public import Motion
    public import Picture

    extension Picture {
        /// A checklist at a moment, to lay over what is behind it.
        ///
        /// The plate, grown about its middle from `1 − settle` of its size to all of it as it settles, is its
        /// `Plate` over the grown rectangle, its coat running over that rectangle, faded by `shown`. Over it stand the heading,
        /// slid in from `slide` left of the left edge, faded by `headed` and toned from its ink to its second
        /// colour; the statement, risen from `rise` below its baseline inside its slot; and the rows.
        public init(_ checklist: Motion.Graphics.Checklist, at moment: Motion.Graphics.Checklist.Moment) {
            let style = checklist.style
            let layout = checklist.layout
            var elements: [Picture.Element] = []
            if moment.shown > 0 {
                let plate = style.plate
                let frame = layout.plate
                let grown = 1 - style.settle + style.settle * moment.settled
                let (left, top) = (frame.llx.underlying, frame.lly.underlying)
                let (wide, tall) = (frame.urx.underlying - left, frame.ury.underlying - top)
                let x = left + (1 - grown) * wide / 2
                let y = top + (1 - grown) * tall / 2
                let rectangle = Picture.Plane.Rectangle(llx: .init(x), lly: .init(y), urx: .init(x + wide * grown), ury: .init(y + tall * grown))
                let whole = plate.elements(rectangle)
                elements.append(contentsOf: moment.shown < 1 ? [.layer(Picture.Layer(Picture(whole), opacity: Float(moment.shown)))] : whole)
            }
            if moment.headed > 0, !checklist.heading.isEmpty {
                let color = style.heading.ink.color.mixed(inSRGBTo: style.heading.toned, at: moment.toned.clamped(to: 0...1))
                let point = Picture.Plane.Point<2>([layout.left - (1 - moment.headed) * style.heading.slide, layout.heading])
                let placed = checklist.headed.placed(.init(.solid(color)), at: point)
                elements.append(moment.headed < 1 ? .layer(Picture.Layer([placed], opacity: Float(moment.headed))) : placed)
            }
            if moment.stated > 0, !checklist.statement.isEmpty {
                let statement = style.statement
                let point = Picture.Plane.Point<2>([layout.left + statement.indent, layout.statement + (1 - moment.stated) * statement.rise])
                let (top, bottom) = statement.slot.span(baseline: layout.statement, size: statement.ink.size)
                let slot = Picture.Plane.Rectangle(llx: layout.plate.llx, lly: .init(top), urx: layout.plate.urx, ury: .init(bottom))
                elements.append(.group(Picture.Group([checklist.stated.placed(.init(.solid(statement.ink.color)), at: point)], clip: Picture.Clip(Picture.Plane.Path(slot)))))
            }
            for (row, state) in zip(checklist.rows, moment.rows) {
                elements.append(.group(Picture.Group(Picture(row, at: state))))
            }
            self.init(elements)
        }
    }
#endif
