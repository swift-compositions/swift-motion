#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// The form of a plate's corners: quarter circles of a radius, continuous corners (quarters of a superellipse
        /// of a radius and an exponent, whose curvature grows from nothing along the corner), or a capsule's half
        /// circles across its shorter side.
        public enum Corners: Sendable, Hashable {
            case circular(Double)
            case continuous(Double, exponent: Double)
            case capsule
        }
    }

    extension Motion.Graphics.Corners {
        /// The tolerance a continuous corner's outline is flattened to, in picture units.
        public static let tolerance: Double = 0.05

        /// The region inside a rectangle with these corners, as a pane of glass takes it.
        public func region(_ rectangle: Picture.Plane.Rectangle) -> Picture.Plane.Region {
            switch self {
            case .circular(let radius): .rectangle(rectangle, radius: radius)
            case .continuous(let radius, let exponent): .superellipse(.init(rectangle, radius: radius, exponent: exponent))
            case .capsule: .capsule(rectangle)
            }
        }

        /// The outline of a rectangle with these corners, as a fill and a stroke take it: for continuous corners the
        /// region's boundary, flattened to within `tolerance`.
        public func path(_ rectangle: Picture.Plane.Rectangle) -> Picture.Plane.Path {
            switch self {
            case .circular(let radius):
                return Picture.Plane.Path(rectangle, radius: .init(radius))
            case .continuous(let radius, let exponent):
                return Picture.Plane.Path(Picture.Plane.Superellipse(rectangle, radius: radius, exponent: exponent), tolerance: .init(Self.tolerance))
            case .capsule:
                let tall = Swift.abs(rectangle.ury.underlying - rectangle.lly.underlying)
                let wide = Swift.abs(rectangle.urx.underlying - rectangle.llx.underlying)
                return Picture.Plane.Path(rectangle, radius: .init(Swift.min(tall, wide) / 2))
            }
        }
    }
#endif
