#if Graphics
    import Motion
    import Picture

    extension Picture {
        /// One line from the start of its first baseline: the mark, the standing characters of each row, and the
        /// caret in the cell after the last of them, all faded by how much of the line shows.
        init(
            _ line: Motion.Graphics.Transcript.Line,
            at moment: Motion.Graphics.Transcript.Line.Moment,
            from origin: Picture.Plane.Point<2>,
            advance: Double,
            style: Motion.Graphics.Transcript.Style
        ) throws(Picture.Text.Error) {
            guard moment.shown > 0 else {
                self = .empty
                return
            }
            var content: [Picture.Element] = []
            let marked = Float(Swift.min(moment.marked, 1))
            let ink: Motion.Graphics.Ink
            switch line.mark {
            case .prompt(let word):
                ink = style.typed
                if marked > 0 { content.append(try style.mark.text(word).placed(.init(.solid(style.mark.color.faded(by: marked))), at: origin)) }
            case .label(let word, let color):
                ink = style.said
                if marked > 0 { content.append(try style.mark.text(word).placed(.init(.solid(color.faded(by: marked))), at: origin)) }
            case .plain:
                ink = style.said
            }
            let start = origin[0] + Double(line.lead) * advance
            let standing = line.standing(moment.typed)
            let rows = line.rows(within: style.columns)
            for (number, row) in rows.enumerated() where row.standing(standing) > 0 {
                let baseline = origin[1] + Double(number) * style.leading
                let text = try ink.text(Swift.String(row.text.prefix(row.standing(standing))))
                content.append(text.placed(.init(.solid(ink.color)), at: Picture.Plane.Point<2>([start, baseline])))
            }
            if moment.caret > 0, let place = rows.lastIndex(where: { $0.start <= standing }) {
                let caret = style.caret
                let cell = start + Double(rows[place].standing(standing)) * advance
                let baseline = origin[1] + Double(place) * style.leading
                let body = Picture.Plane.Rectangle(
                    llx: .init(cell + caret.left),
                    lly: .init(baseline - caret.top),
                    urx: .init(cell + advance - caret.right),
                    ury: .init(baseline + caret.bottom)
                )
                let block: Picture = [.fill(Picture.Plane.Path(body, radius: .init(caret.radius)), .solid(caret.color.faded(by: Float(Swift.min(moment.caret, 1)))))]
                content.append(contentsOf: block.glow(deviation: caret.deviation, strength: Float(caret.strength)).elements)
            }
            let picture = Picture(content)
            self = moment.shown < 1 ? [.layer(Picture.Layer(picture, opacity: Float(moment.shown)))] : picture
        }
    }
#endif
