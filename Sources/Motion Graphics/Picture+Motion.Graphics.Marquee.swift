#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A marquee at a moment: each row that has a moment and has begun to rise, its words repeated a unit
        /// apart from `offset(row:travel:)` left of the region's left edge until past its right edge, their
        /// capitals centred in the row's band, lowered by `(1 − risen)` pitches and clipped to the band inside the
        /// region, so a row rises into its band.
        public init(_ marquee: Motion.Graphics.Marquee, at moment: Motion.Graphics.Marquee.Moment) throws(Picture.Text.Error) {
            let style = marquee.style
            let region = marquee.region
            let (left, right, top, bottom) = (region.llx.underlying, region.urx.underlying, region.lly.underlying, region.ury.underlying)
            let cap = try Picture.Text.Metrics(font: style.ink.font, size: style.ink.size).cap
            var elements: [Picture.Element] = []
            for (index, risen) in zip(0..<Int(clamping: marquee.rows), moment.rows) where risen > 0 {
                let row = Ordinal(UInt(index))
                let text = try marquee.set(row: row)
                let unit = text.width + style.gap
                guard unit > 0 else { continue }
                let face = style.faces.isEmpty ? .filled : style.faces[index % style.faces.count]
                let shape: Picture.Element =
                    switch face {
                    case .filled: .fill(text.path, .solid(style.ink.color))
                    case .outlined(let width): .stroke(text.path, .solid(style.ink.color), width: width, join: .round, cap: .round)
                    }
                let band = top + Double(index) * style.pitch
                let baseline = band + (style.pitch + cap) / 2 + (1 - risen) * style.pitch
                var x = left - (try marquee.offset(row: row, travel: moment.travel))
                var copies: [Picture.Element] = []
                while x < right {
                    copies.append(.group(Picture.Group([shape], transform: .translation(x: x, y: baseline))))
                    x += unit
                }
                let slot = Picture.Plane.Rectangle(
                    llx: .init(left),
                    lly: .init(band),
                    urx: .init(right),
                    ury: .init(Swift.min(band + style.pitch, bottom))
                )
                elements.append(.group(Picture.Group(Picture(copies), clip: Picture.Clip(Picture.Plane.Path(slot)))))
            }
            self.init(elements)
        }
    }
#endif
