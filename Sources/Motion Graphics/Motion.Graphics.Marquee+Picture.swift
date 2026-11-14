#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A marquee at a moment: each row that has a moment and has begun to rise, its words repeated a unit
        /// apart from `offset(row:travel:)` left of the region's left edge until past its right edge, their
        /// capitals centered in the row's band, lowered by `(1 − risen)` times the style's rise (a pitch without one)
        /// and clipped inside the region to the row's slot about its resting baseline, or to its band without one,
        /// so a row rises into its window.
        public init(_ marquee: Motion.Graphics.Marquee, at moment: Motion.Graphics.Marquee.Moment) {
            let style = marquee.style
            let region = marquee.frame
            let (left, right, top, bottom) = (region.llx.underlying, region.urx.underlying, region.lly.underlying, region.ury.underlying)
            let cap = marquee.cap
            var elements: [Picture.Element] = []
            for (index, risen) in zip(0..<Int(clamping: marquee.rows), moment.rows) where risen > 0 {
                let row = Ordinal(UInt(index))
                let text = marquee.set(row: row)
                let unit = text.width + style.gap
                guard unit > 0 else { continue }
                let face = style.faces.isEmpty ? .filled : style.faces[index % style.faces.count]
                let shape: Picture.Element =
                    switch face {
                    case .filled: .fill(text.path, .solid(style.ink.color))
                    case .outlined(let width): .stroke(text.path, .solid(style.ink.color), width: width, join: .round, cap: .round)
                    }
                let band = top + Double(index) * style.pitch
                let resting = band + (style.pitch + cap) / 2
                let baseline = resting + (1 - risen) * (style.rise ?? style.pitch)
                var x = left - marquee.offset(row: row, travel: moment.travel)
                var copies: [Picture.Element] = []
                while x < right {
                    copies.append(.group(Picture.Group([shape], transform: .translation(x: x, y: baseline))))
                    x += unit
                }
                let window =
                    style.slot.map { $0.span(baseline: resting, size: style.ink.size) }
                    ?? (top: band, bottom: band + style.pitch)
                let slot = Picture.Plane.Rectangle(
                    llx: .init(left),
                    lly: .init(Swift.max(window.top, top)),
                    urx: .init(right),
                    ury: .init(Swift.min(window.bottom, bottom))
                )
                elements.append(.group(Picture.Group(Picture(copies), clip: Picture.Clip(Picture.Plane.Path(slot)))))
            }
            self.init(elements)
        }
    }
#endif
