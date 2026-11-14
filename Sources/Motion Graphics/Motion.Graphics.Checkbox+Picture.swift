#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A box at a moment: its edge at `half × min(box, overshoot)` with corners of `radius × min(box, 1)`, the
        /// fill at `half × filled` but never under the least half, glowing at its glow's strength at the flash,
        /// and the tick trimmed to the share drawn.
        public init(_ checkbox: Motion.Graphics.Checkbox, at moment: Motion.Graphics.Checkbox.Moment) {
            let style = checkbox.style
            let centre = checkbox.centre
            func square(_ half: Double, radius: Double) -> Picture.Plane.Path {
                Picture.Plane.Path(
                    Picture.Plane.Rectangle(llx: .init(centre[0] - half), lly: .init(centre[1] - half), urx: .init(centre[0] + half), ury: .init(centre[1] + half)),
                    radius: .init(radius)
                )
            }
            var elements: [Picture.Element] = []
            if moment.box > 0 {
                let grown = style.half * Swift.min(moment.box, style.overshoot)
                elements.append(.stroke(square(grown, radius: style.radius * Swift.min(moment.box, 1)), .solid(style.edge), width: style.pen, join: .round, cap: .round))
            }
            if moment.filled > 0 {
                let filled: Picture = [.fill(square(Swift.max(style.half * moment.filled, style.least), radius: style.radius), .solid(style.fill))]
                let glowing = style.glow.map { $0.applied(to: filled, strength: $0.strength(flash: moment.flash)) } ?? filled
                elements.append(contentsOf: glowing.elements)
            }
            let tick = style.tick.map { Picture.Plane.Point<2>([centre[0] + $0[0], centre[1] + $0[1]]) }
            if moment.stroke > 0, let path = Picture.Plane.Path.polyline(vertices: tick) {
                elements.append(.stroke(path.trimmed(to: .init(Swift.min(moment.stroke, 1))), .solid(style.mark), width: style.weight, join: .round, cap: .round))
            }
            self.init(elements)
        }
    }
#endif
