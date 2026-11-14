#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A progress ring: a faint track round a centre, and over it an arc that turns and fills, glowing. Held
        /// at a share it turns as a spinner that does not know how long it will take; filled by a share that
        /// grows, it is a progress ring; filled whole, it is the whole ring.
        public struct Spinner: Sendable, Hashable {
            public var centre: Picture.Plane.Point<2>

            /// The radius of the ring's middle line.
            public var radius: Double
            public var style: Style

            /// What the glow spares, a picture in the spinner's space whose alpha can be soft; nil for the disc
            /// inside the ring, so the ring glows outward and its middle stays as dark as what is behind.
            public var mask: Picture?

            public init(at centre: Picture.Plane.Point<2>, radius: Double, style: Style, mask: Picture? = nil) {
                self.centre = centre
                self.radius = radius
                self.style = style
                self.mask = mask
            }
        }
    }

    extension Motion.Graphics.Spinner {
        /// The arc at a moment: from the top of the ring turned on by the moment's turn, clockwise on a screen,
        /// over the share of the ring it has filled; nil when it fills nothing. A share of 1 or more is the whole
        /// ring, a closed circle.
        public func arc(at moment: Moment) -> Picture.Plane.Path? {
            let filled = Swift.min(moment.filled, 1)
            guard filled > 0, radius > 0 else { return nil }
            guard filled < 1 else { return Picture.Plane.Path(Picture.Plane.Circle(center: centre, radius: .init(radius))) }
            let start = 2 * Double.pi * moment.turn - Double.pi / 2
            return Picture.Plane.Path(
                Picture.Plane.Arc(center: centre, radius: .init(radius), startAngle: Radian(start), endAngle: Radian(start + 2 * Double.pi * filled))
            )
        }

        /// What the glow spares: the mask, or without one the disc inside the ring, white.
        public var spared: Picture {
            mask ?? [.fill(Picture.Plane.Path(Picture.Plane.Circle(center: centre, radius: .init(Swift.max(radius - style.pen / 2, 0)))), .solid(.white))]
        }
    }
#endif
