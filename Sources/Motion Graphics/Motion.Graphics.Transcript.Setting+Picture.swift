#if Graphics
    import Motion
    import Picture

    extension Picture {
        /// One set line from the start of its first baseline: the mark, the standing glyphs of each row, and the
        /// caret in the cell after the last of them, all faded by how much of the line shows. A row's standing
        /// glyphs are the first of those it was set with.
        init(
            _ setting: Motion.Graphics.Transcript.Setting,
            of mark: Motion.Graphics.Transcript.Line.Mark,
            at moment: Motion.Graphics.Transcript.Line.Moment,
            from origin: Picture.Plane.Point<2>,
            advance: Double,
            style: Motion.Graphics.Transcript.Style
        ) {
            guard moment.shown > 0 else {
                self = .empty
                return
            }
            var content: [Picture.Element] = []
            let marked = Float(Swift.min(moment.marked, 1))
            if marked > 0, let text = setting.mark {
                let color: Picture.Color
                switch mark {
                case .label(_, let own): color = own
                case .prompt, .plain: color = style.mark.color
                }
                content.append(text.placed(.init(.solid(color.faded(by: marked))), at: origin))
            }
            let start = origin[0] + Double(setting.lead) * advance
            let standing = Motion.Graphics.standing(moment.typed, of: setting.length)
            let rows = setting.rows
            for (number, row) in rows.enumerated() where row.standing(standing) > 0 {
                let baseline = origin[1] + Double(number) * style.leading
                let path = row.path(standing: row.standing(standing))
                content.append(.group(Picture.Group([.fill(path, .solid(setting.ink.color))], transform: .translation(x: start, y: baseline))))
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
