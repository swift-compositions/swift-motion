#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A spinner at a moment: the track round the whole ring, and over it the arc of `arc(at:)`, both in the
        /// pen with round caps; the arc glows at its rest strength plus its flash, sparing the disc inside the
        /// ring, and the whole is faded by how much shows.
        public init(_ spinner: Motion.Graphics.Spinner, at moment: Motion.Graphics.Spinner.Moment) {
            guard moment.shown > 0, spinner.radius > 0 else {
                self = .empty
                return
            }
            let style = spinner.style
            var content: Picture = []
            if style.track.alpha > 0 {
                let ring = Picture.Plane.Path(Picture.Plane.Circle(center: spinner.centre, radius: .init(spinner.radius)))
                content.elements.append(.stroke(ring, .solid(style.track), width: style.pen, join: .round, cap: .round))
            }
            if let arc = spinner.arc(at: moment) {
                let lit: Picture = [.stroke(arc, .solid(style.ink), width: style.pen, join: .round, cap: .round)]
                let inside = Swift.max(spinner.radius - style.pen / 2, 0)
                let hole: Picture = [.fill(Picture.Plane.Path(Picture.Plane.Circle(center: spinner.centre, radius: .init(inside))), .solid(.white))]
                let strength = style.glow.rest + style.glow.flash * moment.flash
                content.elements.append(contentsOf: lit.glow(deviation: style.glow.deviation, strength: Float(strength), sparing: hole).elements)
            }
            self = moment.shown < 1 ? [.layer(Picture.Layer(content, opacity: Float(moment.shown)))] : content
        }
    }
#endif
