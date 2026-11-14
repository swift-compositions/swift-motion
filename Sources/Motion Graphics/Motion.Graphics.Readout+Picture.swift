#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A readout at a moment.
        ///
        /// The line is set once in tabular figures, so the count's digits take one advance each and the count,
        /// the word and the total stand where the line puts them whatever the count reads. The plate is the
        /// line's width and its insets wide; over its surface go its edge and any flash in the lit accent, the label
        /// and the total in the ink, the bar's track, and the moment's count and the filled bar in the accent,
        /// glowing. The whole stands where `transform(at:)` puts it, growing in about the plate's middle, turned
        /// and dropped, and fades in `fade` times faster than it grows, times its light.
        public init(_ readout: Motion.Graphics.Readout, at moment: Motion.Graphics.Readout.Moment) {
            guard moment.shown > 0, moment.light > 0 else {
                self = .empty
                return
            }
            let style = readout.style
            let ink = style.ink
            let plate = style.plate
            let line = readout.line
            let frame = readout.plate
            let (left, top) = (frame.llx.underlying, frame.lly.underlying)
            let (start, end) = (left + plate.inset, frame.urx.underlying - plate.inset)
            let baseline = top + plate.baseline
            let glyphs = line.glyphs
            let counted = Picture.Text.length(of: readout.label) + 1
            let after = counted + readout.origins.count + 1
            let x = { (place: Int) in start + (place < glyphs.count ? glyphs[place].origin[0] : line.width) }
            let lit = style.lit(heat: moment.heat, finished: moment.finished)
            let hot = Swift.max(moment.heat, moment.finished)
            let clamp = { (value: Double) in Float(Swift.min(Swift.max(value, 0), 1)) }
            let body = plate.corners.path(frame)
            var content = Picture(
                plate.surface.elements(frame, corners: plate.corners)
                    + [.stroke(body, .solid(lit.faded(by: clamp(plate.edge + plate.heat * hot))), width: plate.pen, join: .round, cap: .round)]
            )
            if moment.flash > 0 { content.elements.append(.fill(body, .solid(lit.faded(by: clamp(plate.flash * moment.flash))))) }
            content.elements.append(readout.opening.placed(.init(.solid(ink.color)), at: Picture.Plane.Point<2>([start, baseline])))
            content.elements.append(readout.closing.placed(.init(.solid(ink.color)), at: Picture.Plane.Point<2>([x(after), baseline])))
            let bar = style.bar
            let track = { (width: Double) in
                Picture.Plane.Path(
                    Picture.Plane.Rectangle(llx: .init(start), lly: .init(top + bar.top), urx: .init(start + width), ury: .init(top + bar.top + bar.height)),
                    radius: .init(bar.height / 2)
                )
            }
            content.elements.append(.fill(track(end - start), .solid(bar.track)))
            let share = readout.share(of: moment.count) * Swift.min(moment.shown, 1)
            let glowing: Picture = [
                .group(Picture.Group([.fill(readout.path(of: moment.count), .solid(lit))], transform: .translation(x: x(counted), y: baseline))),
                .fill(track(Swift.max((end - start) * share, bar.height)), .solid(lit)),
            ]
            let strength = style.glow.rest + style.glow.heat * hot + style.glow.flash * moment.flash
            content.elements.append(contentsOf: glowing.glow(deviation: style.glow.deviation, strength: Float(strength)).elements)
            let placed: Picture = [.group(Picture.Group(content, transform: readout.transform(at: moment)))]
            let opacity = Swift.min(moment.shown * style.fade, 1) * moment.light
            self = opacity < 1 ? [.layer(Picture.Layer(placed, opacity: Float(opacity)))] : placed
        }
    }
#endif
