#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A checklist at a moment, to lay over what is behind it.
        ///
        /// The plate, grown about its middle from `1 − settle` of its size to all of it as it settles, is its
        /// surface inside its corners, then its coat and edge, all faded together by `shown`. Over it stand the heading,
        /// slid in from `slide` left of the left edge, faded by `headed` and toned from its ink to its second
        /// colour; the statement, risen from `rise` below its baseline inside its slot; and the rows.
        public init(_ checklist: Motion.Graphics.Checklist, at moment: Motion.Graphics.Checklist.Moment) throws(Picture.Text.Error) {
            let style = checklist.style
            let layout = checklist.layout
            var elements: [Picture.Element] = []
            if moment.shown > 0 {
                let plate = style.plate
                let frame = layout.plate
                let grown = 1 - plate.settle + plate.settle * moment.settled
                let (left, top) = (frame.llx.underlying, frame.lly.underlying)
                let (wide, tall) = (frame.urx.underlying - left, frame.ury.underlying - top)
                let x = left + (1 - grown) * wide / 2
                let y = top + (1 - grown) * tall / 2
                let rectangle = Picture.Plane.Rectangle(llx: .init(x), lly: .init(y), urx: .init(x + wide * grown), ury: .init(y + tall * grown))
                let body = plate.corners.path(rectangle)
                let surface = plate.surface.elements(rectangle, corners: plate.corners)
                let coat = Picture.Gradient([.init(offset: 0, color: plate.top), .init(offset: 1, color: plate.foot)])
                let tint = Picture.Element.shape(
                    Picture.Shape(
                        body,
                        fill: .init(.linear(.init(from: Picture.Plane.Point<2>([0, top]), to: Picture.Plane.Point<2>([0, top + tall]), coat))),
                        stroke: .init(.solid(plate.edge), pen: .init(width: .init(plate.pen), join: .round, cap: .round))
                    )
                )
                let whole = surface + [tint]
                elements.append(contentsOf: moment.shown < 1 ? [.layer(Picture.Layer(Picture(whole), opacity: Float(moment.shown)))] : whole)
            }
            if moment.headed > 0, !checklist.heading.isEmpty {
                let ink = style.heading.ink
                let heading = try Picture.Text(checklist.heading, font: ink.font, size: ink.size, tracking: style.heading.tracking)
                let color = ink.color.mixed(inSRGBTo: style.heading.toned, at: Swift.min(Swift.max(moment.toned, 0), 1))
                let point = Picture.Plane.Point<2>([layout.left - (1 - moment.headed) * style.heading.slide, layout.heading])
                let placed = heading.placed(.init(.solid(color)), at: point)
                elements.append(moment.headed < 1 ? .layer(Picture.Layer([placed], opacity: Float(moment.headed))) : placed)
            }
            if moment.stated > 0, !checklist.statement.isEmpty {
                let statement = style.statement
                let text = try statement.ink.text(checklist.statement)
                let point = Picture.Plane.Point<2>([layout.left + statement.indent, layout.statement + (1 - moment.stated) * statement.rise])
                let top = layout.statement - statement.above
                let slot = Picture.Plane.Rectangle(llx: layout.plate.llx, lly: .init(top), urx: layout.plate.urx, ury: .init(top + statement.height))
                elements.append(.group(Picture.Group([text.placed(.init(.solid(statement.ink.color)), at: point)], clip: Picture.Clip(Picture.Plane.Path(slot)))))
            }
            for (row, state) in zip(checklist.rows, moment.rows) {
                elements.append(.group(Picture.Group(try Picture(row, at: state))))
            }
            self.init(elements)
        }
    }
#endif
