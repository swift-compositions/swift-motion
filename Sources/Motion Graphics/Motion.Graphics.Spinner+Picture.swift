#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A spinner at a moment: the track round the whole ring, glowing by its glow, and over it the arc of
        /// `arc(at:)`, glowing by its own, both in the pen with round caps. Each glow is at its strength at the
        /// moment's flash and spares the spinner's `spared`, its mask or, without one, the disc inside the ring;
        /// a glow of strength 0, or none, adds no light. The whole is faded by how much shows.
        public init(_ spinner: Motion.Graphics.Spinner, at moment: Motion.Graphics.Spinner.Moment) {
            guard moment.shown > 0, spinner.radius > 0 else {
                self = .empty
                return
            }
            let style = spinner.style
            var content: Picture = []
            if style.track.color.alpha > 0 {
                let ring = Picture.Plane.Path(Picture.Plane.Circle(center: spinner.centre, radius: .init(spinner.radius)))
                let track: Picture = [.stroke(ring, .solid(style.track.color), width: style.pen, join: .round, cap: .round)]
                let glowing = style.track.glow.map { $0.applied(to: track, strength: $0.strength(flash: moment.flash), sparing: spinner.spared) } ?? track
                content.elements.append(contentsOf: glowing.elements)
            }
            if let arc = spinner.arc(at: moment) {
                let lit: Picture = [.stroke(arc, .solid(style.arc.color), width: style.pen, join: .round, cap: .round)]
                let glowing = style.arc.glow.map { $0.applied(to: lit, strength: $0.strength(flash: moment.flash), sparing: spinner.spared) } ?? lit
                content.elements.append(contentsOf: glowing.elements)
            }
            self = moment.shown < 1 ? [.layer(Picture.Layer(content, opacity: Float(moment.shown)))] : content
        }
    }
#endif
