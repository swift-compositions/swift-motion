#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A ring of light thrown out from a point: it sets out at a radius, travels outward as its moment
        /// spreads, thins and fades to nothing as it goes, and leaves echoes behind it, each fainter than the one
        /// before.
        public struct Shockwave: Sendable, Hashable {
            public var centre: Picture.Plane.Point<2>
            public var style: Style

            public init(at centre: Picture.Plane.Point<2>, style: Style) {
                self.centre = centre
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Shockwave {
        /// The rings at a moment, the lead ring first and then its echoes, each the radius, pen and colour it is
        /// drawn in. The lead ring's own spread is the moment's times `1 + count × lag`, and echo k's is the lead's
        /// less k lags, so the last echo goes as the moment reaches 1. A ring is drawn while its own spread lies
        /// strictly between 0 and 1. At a spread s a ring's radius is `radius + reach × s`, which never shrinks
        /// as s grows; its pen is `pen` mixed toward `least` by s; and its colour is `color` mixed in sRGB toward
        /// `finish` by s, faded by `(1 − s)` to the power `fall` and by `trail.fade` once for each step behind,
        /// so each ring's light falls to nothing as it ends, and at a moment of 1 nothing is left.
        public func rings(at moment: Moment) -> [Ring] {
            let style = self.style
            guard moment.spread > 0, moment.spread < 1 else { return [] }
            var rings: [Ring] = []
            var echo = 0
            let lag = Swift.max(style.trail.lag, 0)
            var spread = moment.spread * (1 + Double(Int(clamping: style.trail.count)) * lag)
            var light = 1.0
            while spread > 0, echo <= Int(clamping: style.trail.count) {
                if spread < 1 {
                    let left = (0..<Int(clamping: style.fall)).reduce(light) { left, _ in left * (1 - spread) }
                    rings.append(
                        Ring(
                            radius: style.radius + style.reach * spread,
                            pen: style.pen + (style.least - style.pen) * spread,
                            color: style.color.mixed(inSRGBTo: style.finish, at: spread).faded(by: Float(Swift.min(Swift.max(left, 0), 1)))
                        )
                    )
                }
                guard lag > 0 else { break }
                echo += 1
                spread -= lag
                light *= style.trail.fade
            }
            return rings
        }
    }
#endif
