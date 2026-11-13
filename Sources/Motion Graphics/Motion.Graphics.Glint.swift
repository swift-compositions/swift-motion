#if Graphics
    public import Motion
    import Numeric
    public import Picture

    extension Motion.Graphics {
        /// A streak of light that sweeps once across a shape: a band, slanted from upright, brightest along its
        /// middle and clear at its sides, painted only where the shape is, glowing and adding its light to what
        /// is behind. It sets out clear of the shape on one side and ends clear of it on the other.
        public struct Glint: Sendable, Hashable {
            /// The shape the light falls on, such as a text's path where it stands.
            public var shape: Picture.Plane.Path
            public var style: Style

            public init(over shape: Picture.Plane.Path, style: Style) {
                self.shape = shape
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Glint {
        /// The way the band travels: across it, x turned toward y by the slant.
        var direction: (x: Double, y: Double) {
            (Double.cos(style.slant), Double.sin(style.slant))
        }

        /// How far along the band's way its middle stands at a sweep: from half a band before the shape's box to
        /// half a band past it, evenly, so at 0 and at 1 no point of the shape is under the band, and the middle
        /// never goes back as the sweep grows. Nil for a shape that covers nothing.
        public func middle(at moment: Moment) -> Double? {
            guard let box = shape.boundingBox else { return nil }
            let way = direction
            let along = [
                (box.llx.underlying, box.lly.underlying), (box.urx.underlying, box.lly.underlying),
                (box.llx.underlying, box.ury.underlying), (box.urx.underlying, box.ury.underlying),
            ].map { $0.0 * way.x + $0.1 * way.y }
            guard let low = along.min(), let high = along.max() else { return nil }
            let half = style.width / 2
            return low - half + (high - low + style.width) * moment.swept
        }

        /// The band's paint at a moment: a gradient across the band, clear at its sides and the colour, faded by
        /// its strength and the moment's light, at its middle. Nil when the band is off the shape: before the
        /// sweep starts, after it ends, or with no light.
        public func band(at moment: Moment) -> Picture.Paint.Linear? {
            guard moment.swept > 0, moment.swept < 1, moment.light > 0, style.width > 0, let middle = middle(at: moment) else { return nil }
            let way = direction
            let half = style.width / 2
            let peak = style.color.faded(by: Float(Swift.min(Swift.max(style.strength * moment.light, 0), 1)))
            let gradient = Picture.Gradient([
                .init(offset: 0, color: style.color.faded(by: 0)),
                .init(offset: 0.5, color: peak),
                .init(offset: 1, color: style.color.faded(by: 0)),
            ])
            return Picture.Paint.Linear(
                from: Picture.Plane.Point<2>([(middle - half) * way.x, (middle - half) * way.y]),
                to: Picture.Plane.Point<2>([(middle + half) * way.x, (middle + half) * way.y]),
                gradient
            )
        }
    }
#endif
