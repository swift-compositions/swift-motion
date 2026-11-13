#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A shockwave at a moment: each of its `rings(at:)` stroked round its centre, the echoes under the lead
        /// ring, glowing together and adding their light to what is behind. With no ring it is empty.
        public init(_ shockwave: Motion.Graphics.Shockwave, at moment: Motion.Graphics.Shockwave.Moment) {
            let rings = shockwave.rings(at: moment).filter { $0.radius > 0 && $0.pen > 0 }
            guard !rings.isEmpty else {
                self = .empty
                return
            }
            let strokes: Picture = Picture(
                rings.reversed().map { ring in
                    .stroke(
                        Picture.Plane.Path(Picture.Plane.Circle(center: shockwave.centre, radius: .init(ring.radius))),
                        .solid(ring.color),
                        width: ring.pen,
                        join: .round,
                        cap: .round
                    )
                }
            )
            let style = shockwave.style
            self = [.layer(Picture.Layer(strokes.glow(deviation: style.deviation, strength: Float(style.strength)), operator: .lighter))]
        }
    }
#endif
