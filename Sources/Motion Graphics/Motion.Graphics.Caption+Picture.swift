#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A caption at a moment: its plate, sized for the whole line however much of it is typed, and the line
        /// on it; both stand `(1 − risen) × rise` below their place and are faded by how much shows.
        public init(_ caption: Motion.Graphics.Caption, at moment: Motion.Graphics.Caption.Moment) {
            guard moment.shown > 0 else {
                self = .empty
                return
            }
            let style = caption.style.plate
            let plate = style.surface.elements(caption.plate, corners: style.corners)
            let line = Picture(caption.transcript, at: Motion.Graphics.Transcript.Moment([moment.line]))
            let content = Picture(plate + line.elements)
            let faded: Picture = moment.shown < 1 ? [.layer(Picture.Layer(content, opacity: Float(moment.shown)))] : content
            let lowered = (1 - moment.risen) * caption.style.rise
            self = lowered == 0 ? faded : [.group(Picture.Group(faded, transform: .translation(x: 0, y: lowered)))]
        }
    }
#endif
