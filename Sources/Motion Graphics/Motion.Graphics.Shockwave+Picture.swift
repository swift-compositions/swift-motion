#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A shockwave at a moment: each of its `rings(at:)` stroked round its centre, the echoes under the lead
        /// ring, a ring of no radius a disc the pen wide, glowing together if the style has a glow and adding their
        /// light to what is behind. With no ring it is empty.
        public init(_ shockwave: Motion.Graphics.Shockwave, at moment: Motion.Graphics.Shockwave.Moment) {
            let rings = shockwave.rings(at: moment).filter { $0.radius >= 0 && $0.pen > 0 }
            guard !rings.isEmpty else {
                self = .empty
                return
            }
            let strokes: Picture = Picture(
                rings.reversed().map { ring in
                    guard ring.radius > 0 else {
                        return .fill(Picture.Plane.Path(Picture.Plane.Circle(center: shockwave.centre, radius: .init(ring.pen / 2))), .solid(ring.color))
                    }
                    return .stroke(
                        Picture.Plane.Path(Picture.Plane.Circle(center: shockwave.centre, radius: .init(ring.radius))),
                        .solid(ring.color),
                        width: ring.pen,
                        join: .round,
                        cap: .round
                    )
                }
            )
            guard let glow = shockwave.style.glow else {
                self = [.layer(Picture.Layer(strokes, operator: .lighter))]
                return
            }
            self = [.layer(Picture.Layer(glow.applied(to: strokes), operator: .lighter))]
        }
    }
#endif
