#if Graphics
    public import Motion
    import Numeric
    public import Picture

    extension Picture {
        /// A twinkle at a moment: each ray a glow drawn out along its angle, turned on by `turn × shone`, to its
        /// length times the shine and thinned to its width times the shine, and a glow at the core of the radius
        /// times the shine, all in the colours faded by the shine, in a layer that adds their light to what is
        /// behind. Outside the shine it is empty.
        public init(_ twinkle: Motion.Graphics.Twinkle, at moment: Motion.Graphics.Twinkle.Moment) {
            let shine = moment.shine
            guard shine > 0 else {
                self = .empty
                return
            }
            let style = twinkle.style
            let (x, y) = (twinkle.centre[0], twinkle.centre[1])
            let origin = Picture.Plane.Point<2>([0.0, 0.0])
            var lights: [Picture.Element] = style.rays.map { ray in
                let angle = ray.angle + style.turn * moment.shone
                let (c, s) = (Double.cos(angle), Double.sin(angle))
                let (long, thin) = (ray.length * shine, ray.width * shine)
                let drawn = Picture.Transform(rows: [[long * c, -thin * s, x], [long * s, thin * c, y]])
                return .group(Picture.Group([.glow(style.color.faded(by: Float(shine)), center: origin, radius: 1)], transform: drawn))
            }
            if style.radius > 0 {
                lights.append(.glow(style.core.faded(by: Float(shine)), center: twinkle.centre, radius: style.radius * shine))
            }
            self = [.layer(Picture.Layer(Picture(lights), operator: .lighter))]
        }
    }
#endif
