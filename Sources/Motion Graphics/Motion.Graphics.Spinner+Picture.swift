#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A spinner at a moment: the track round the whole ring, and over it the arc of `arc(at:)`, both in the
        /// pen with round caps; the arc glows at its glow's strength at the flash, sparing the spinner's mask or,
        /// without one, the disc inside the ring, with no glow at all at a strength of 0 or without a glow; and the whole is faded by how
        /// much shows.
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
                let glowing = style.glow.map { $0.applied(to: lit, strength: $0.strength(flash: moment.flash), sparing: spinner.spared) } ?? lit
                content.elements.append(contentsOf: glowing.elements)
            }
            self = moment.shown < 1 ? [.layer(Picture.Layer(content, opacity: Float(moment.shown)))] : content
        }
    }
#endif
