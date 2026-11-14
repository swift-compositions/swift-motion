#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A glint at a moment: the shape filled with the band of `band(at:)`, glowing by its glow, in a layer that adds its
        /// light to what is behind. With no band it is empty.
        public init(_ glint: Motion.Graphics.Glint, at moment: Motion.Graphics.Glint.Moment) {
            guard let band = glint.band(at: moment) else {
                self = .empty
                return
            }
            let lit: Picture = [.fill(glint.shape, .linear(band))]
            self = [.layer(Picture.Layer(glint.style.glow.map { $0.applied(to: lit) } ?? lit, operator: .lighter))]
        }
    }
#endif
