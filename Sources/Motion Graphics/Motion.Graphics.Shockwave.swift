#if Graphics
    import Standard_Library_Extensions
    public import Motion
    public import Picture
    import Timeline

    extension Motion.Graphics {
        /// A ring of light thrown out from a point: it sets out at a radius, travels outward as its moment
        /// spreads, thins and fades to nothing as it goes, and leaves echoes behind it, each fainter than the one
        /// before.
        public struct Shockwave: Sendable {
            /// The point the wave is thrown from: its rings' center.
            public var place: Picture.Plane.Point<2>
            public var style: Style

            public init(at place: Picture.Plane.Point<2>, style: Style) {
                self.place = place
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Shockwave {
        /// The rings at a moment, the lead ring first and then its echoes, each the radius, pen, softness, light
        /// and colour it is drawn in. The lead ring's own spread is the moment's times `1 + count × lag`, and echo
        /// k's is the lead's less k lags, so the last echo goes as the moment reaches 1; without a trail the lead
        /// ring is the only one. A ring is drawn while its own spread lies from 0 up to 1, not including 1: at 0 it
        /// is the wave just thrown, its starting ring at full light, which for a starting radius of 0 is a point of
        /// light. At a spread s a ring's radius is `radius + reach × e(s)` for e the style's `travel`; its pen is
        /// `pen` mixed toward `least` by s and its softness `soft` toward `softened`; its light is the style's
        /// `fall` at `1 − s`, times `trail.fade` once for each step behind; and its colour is `color` mixed in
        /// sRGB toward `finish` by s, faded by that light, so each ring's light falls to nothing as it ends, and at
        /// a moment of 1 nothing is left.
        public func rings(at moment: Moment) -> [Ring] {
            let style = self.style
            guard moment.spread >= 0, moment.spread < 1 else { return [] }
            let trail = style.trail ?? Style.Trail(count: .zero, lag: 0, fade: 1)
            var rings: [Ring] = []
            var echo = 0
            let lag = Swift.max(trail.lag, 0)
            var spread = moment.spread * (1 + Double(Int(clamping: trail.count)) * lag)
            var light = 1.0
            while spread >= 0, echo <= Int(clamping: trail.count) {
                if spread < 1 {
                    let left = (light * style.fall.progress(1 - spread, 1)).clamped(to: 0...1)
                    rings.append(
                        Ring(
                            radius: style.radius + style.reach * style.travel.progress(spread, 1),
                            pen: style.pen + (style.least - style.pen) * spread,
                            softness: style.soft + (style.softened - style.soft) * spread,
                            light: left,
                            color: style.color.mixed(inSRGBTo: style.finish, at: spread).faded(by: Float(left))
                        )
                    )
                }
                guard lag > 0 else { break }
                echo += 1
                spread -= lag
                light *= trail.fade
            }
            return rings
        }

        /// How brightly the passing wave lights a thing at a distance from its center at a moment, 0 to 1: the
        /// brightest of its rings' `light(at:)` there, so a caller flashes what the wave passes by the law the
        /// rings are drawn with.
        public func light(at distance: Double, moment: Moment) -> Double {
            rings(at: moment).reduce(0) { Swift.max($0, $1.light(at: distance)) }
        }
    }
#endif
