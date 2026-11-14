#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Readout {
        /// A readout's look: the ink of its label and total, the accent the count and the bar are lit in, its
        /// plate and where the type stands on it, its bar, its glow, and how it grows in.
        public struct Style: Sendable {
            /// The label's and the total's ink; the count takes its font and size.
            public var ink: Motion.Graphics.Ink

            /// The accent's colours from cold to hot, evenly spaced: a heat between two of them mixes them as
            /// written, in sRGB.
            public var accent: [Picture.Color]

            /// The accent's colour once the readout is finished.
            public var finish: Picture.Color

            /// The plate; its edge, if it has one, is drawn in the accent at the edge's alpha, whatever its own
            /// colour.
            public var plate: Motion.Graphics.Plate

            /// The plate's height, the inset of the type from its sides, and the type's baseline below its top.
            public var height: Double

            public var inset: Double

            public var baseline: Double

            /// The alpha of the plate's edge in the accent at rest, and of a full flash over the plate.
            public var edge: Double

            public var flash: Double

            public var bar: Bar

            /// The glow of the count and the bar, brightened by heat and flash; nil for none.
            public var glow: Motion.Graphics.Glow?

            /// What full heat adds to the edge's alpha and the glow's strength.
            public var heat: Heat

            /// The share of its size the readout lacks before it has grown in.
            public var grow: Double

            /// How many times faster than it grows it comes in from nothing.
            public var fade: Double

            /// How its numbers are set: tabular by default, so the count's digits stand still as it counts;
            /// `.cells` with a share for punctuation keeps a point or a comma among them from moving them either.
            public var figures: Picture.Text.Figures

            public init(
                ink: Motion.Graphics.Ink,
                accent: [Picture.Color],
                finish: Picture.Color,
                plate: Motion.Graphics.Plate,
                height: Double,
                inset: Double,
                baseline: Double,
                edge: Double,
                flash: Double,
                bar: Bar,
                glow: Motion.Graphics.Glow?,
                heat: Heat,
                grow: Double,
                fade: Double,
                figures: Picture.Text.Figures = .tabular
            ) {
                self.ink = ink
                self.accent = accent
                self.finish = finish
                self.plate = plate
                self.height = height
                self.inset = inset
                self.baseline = baseline
                self.edge = edge
                self.flash = flash
                self.bar = bar
                self.glow = glow
                self.heat = heat
                self.grow = grow
                self.fade = fade
                self.figures = figures
            }
        }
    }

    extension Motion.Graphics.Readout.Style {
        /// The accent at a heat and a finish: the heat's place among the accent's colours, each pair mixed as
        /// written, then mixed toward the finish by how finished it is.
        public func lit(heat: Double, finished: Double) -> Picture.Color {
            let clamp = { (value: Double) in Swift.min(Swift.max(value, 0), 1) }
            guard let last = accent.indices.last else { return finish }
            let place = clamp(heat) * Double(last)
            let low = Swift.min(Int(place.rounded(.down)), last)
            let high = Swift.min(low + 1, last)
            let warm = accent[low].mixed(inSRGBTo: accent[high], at: place - Double(low))
            return warm.mixed(inSRGBTo: finish, at: clamp(finished))
        }
    }
#endif
