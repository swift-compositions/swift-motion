#if Graphics
    public import Motion
    public import Picture
    import Timeline

    extension Motion.Graphics {
        /// A ring of light thrown out from a point: it sets out at a radius, travels outward as its moment
        /// spreads, thins and fades to nothing as it goes, and leaves echoes behind it, each fainter than the one
        /// before.
        public struct Shockwave: Sendable {
            public var centre: Picture.Plane.Point<2>
            public var style: Style

            public init(at centre: Picture.Plane.Point<2>, style: Style) {
                self.centre = centre
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Shockwave {
        /// The rings at a moment, the lead ring first and then its echoes, each the radius, pen, light and colour it
        /// is drawn in. The lead ring's own spread is the moment's times `1 + count × lag`, and echo k's is the
        /// lead's less k lags, so the last echo goes as the moment reaches 1. A ring is drawn while its own spread
        /// lies from 0 up to 1, not including 1: at 0 it is the wave just thrown, its starting ring at full light,
        /// which for a starting radius of 0 is a point of light. At a spread s a ring's radius is
        /// `radius + reach × e(s)` for e the style's `travel`; its pen is `pen` mixed toward `least` by s; its light
        /// is `(1 − s)` to the power `fall`, times `trail.fade` once for each step behind; and its colour is `color`
        /// mixed in sRGB toward `finish` by s, faded by that light, so each ring's light falls to nothing as it ends,
        /// and at a moment of 1 nothing is left.
        public func rings(at moment: Moment) -> [Ring] {
            let style = self.style
            guard moment.spread >= 0, moment.spread < 1 else { return [] }
            var rings: [Ring] = []
            var echo = 0
            let lag = Swift.max(style.trail.lag, 0)
            var spread = moment.spread * (1 + Double(Int(clamping: style.trail.count)) * lag)
            var light = 1.0
            while spread >= 0, echo <= Int(clamping: style.trail.count) {
                if spread < 1 {
                    let left = Swift.min(Swift.max((0..<Int(clamping: style.fall)).reduce(light) { left, _ in left * (1 - spread) }, 0), 1)
                    rings.append(
                        Ring(
                            radius: style.radius + style.reach * style.travel.progress(spread, 1),
                            pen: style.pen + (style.least - style.pen) * spread,
                            light: left,
                            color: style.color.mixed(inSRGBTo: style.finish, at: spread).faded(by: Float(left))
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

        /// How brightly the passing wave lights a thing at a distance from its centre at a moment, 0 to 1: the
        /// brightest of its rings' `light(at:)` there, so a caller flashes what the wave passes by the law the
        /// rings are drawn with.
        public func light(at distance: Double, moment: Moment) -> Double {
            rings(at: moment).reduce(0) { Swift.max($0, $1.light(at: distance)) }
        }
    }
#endif
