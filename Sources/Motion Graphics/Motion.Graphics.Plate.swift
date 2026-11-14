#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A plate a component stands on: its surface inside its corners, and over it an optional coat, a
        /// gradient from the plate's top to its foot, and an optional edge round its outline. Where it stands, its
        /// insets and its baselines are the component's.
        public struct Plate: Sendable, Hashable {
            public var surface: Surface

            public var corners: Corners

            public var edge: Edge?

            public var coat: Picture.Gradient?

            public init(surface: Surface, corners: Corners, edge: Edge? = nil, coat: Picture.Gradient? = nil) {
                self.surface = surface
                self.corners = corners
                self.edge = edge
                self.coat = coat
            }
        }
    }

    extension Motion.Graphics.Plate {
        /// The plate over a rectangle: the surface's `elements(_:corners:)`, then, with a coat or an edge, one shape
        /// of the corners' outline filled with the coat from the rectangle's top to its foot and stroked with the
        /// edge's pen, its joins and caps round.
        public func elements(_ rectangle: Picture.Plane.Rectangle) -> [Picture.Element] {
            elements(rectangle, outline: corners.path(rectangle))
        }

        /// The plate over a rectangle whose outline, the corners' path of it, the caller has already made, as a
        /// caller that also lays something over the outline has.
        public func elements(_ rectangle: Picture.Plane.Rectangle, outline: Picture.Plane.Path) -> [Picture.Element] {
            let surface = surface.elements(rectangle, corners: corners)
            guard edge != nil || coat != nil else { return surface }
            let (top, foot) = (rectangle.lly.underlying, rectangle.ury.underlying)
            let fill = coat.map { coat in
                Picture.Shape.Fill(.linear(.init(from: Picture.Plane.Point<2>([0, top]), to: Picture.Plane.Point<2>([0, foot]), coat)))
            }
            let stroke = edge.map { edge in
                Picture.Shape.Stroke(.solid(edge.color), pen: .init(width: .init(edge.pen), join: .round, cap: .round))
            }
            return surface + [.shape(Picture.Shape(outline, fill: fill, stroke: stroke))]
        }
    }
#endif
