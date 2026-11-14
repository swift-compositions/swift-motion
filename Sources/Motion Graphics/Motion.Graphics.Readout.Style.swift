#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Readout {
        /// A readout's look: the ink of its label and total, the accent the count and the bar are lit in, its
        /// plate, its bar, its glow, how it grows in, and the point it turns about when knocked.
        public struct Style: Sendable {
            /// The label's and the total's ink; the count takes its font and size.
            public var ink: Motion.Graphics.Ink

            /// The accent's colours from cold to hot, evenly spaced: a heat between two of them mixes them as
            /// written, in sRGB.
            public var accent: [Picture.Color]

            /// The accent's colour once the readout is finished.
            public var finish: Picture.Color

            public var plate: Plate
            public var bar: Bar
            public var glow: Glow

            /// The share of its size the readout lacks before it has grown in.
            public var grow: Double

            /// How many times faster than it grows it comes in from nothing.
            public var fade: Double

            /// The point it turns about, from the plate's upper left corner.
            public var pivot: Picture.Plane.Point<2>

            /// How its numbers are set: tabular by default, so the count's digits stand still as it counts;
            /// `.cells` with a share for punctuation keeps a point or a comma among them from moving them either.
            public var figures: Picture.Text.Figures

            public init(
                ink: Motion.Graphics.Ink,
                accent: [Picture.Color],
                finish: Picture.Color,
                plate: Plate,
                bar: Bar,
                glow: Glow,
                grow: Double,
                fade: Double,
                pivot: Picture.Plane.Point<2>,
                figures: Picture.Text.Figures = .tabular
            ) {
                self.ink = ink
                self.accent = accent
                self.finish = finish
                self.plate = plate
                self.bar = bar
                self.glow = glow
                self.grow = grow
                self.fade = fade
                self.pivot = pivot
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
