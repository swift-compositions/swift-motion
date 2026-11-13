#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A line of type whose letters arrive one by one: each drops or rises into its place, shrinks or grows to
        /// its size about its own middle and comes up from clear, and with a moment past 1 it overshoots and
        /// settles back, as a spring does. The line is made of runs, set as one line so the spacing between them
        /// is the font's, and each run takes its own look from the style.
        public struct Title: Sendable {
            /// The words of the runs, in order; run i takes the `i mod n`th of the style's n runs.
            public var runs: [Swift.String]

            /// A point of the line's baseline: its left end, its middle or its right end, as `anchor` says.
            public var place: Picture.Plane.Point<2>
            public var anchor: Picture.Text.Alignment
            public var style: Style

            public init(_ runs: [Swift.String], at place: Picture.Plane.Point<2>, anchor: Picture.Text.Alignment, style: Style) {
                self.runs = runs
                self.place = place
                self.anchor = anchor
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Title {
        /// The whole line set in the style's font at its size.
        public var text: Picture.Text {
            get throws(Picture.Text.Error) {
                try Picture.Text(runs.joined(), font: style.font, size: style.size)
            }
        }

        /// The letters at a moment: each glyph of `text` that draws ink and has a moment above 0, with the
        /// transform that puts it where it stands, its run's colour and its opacity. A glyph's moment e takes it
        /// from `rise` sizes below its place (above for a negative rise) and `1 + grow` times its size about the
        /// middle of its ink across and of its capitals down, to its place at e = 1, by `1 − e` of each; its
        /// opacity is `fade × e`, at most 1. At e = 1 every letter stands where the whole line placed at the
        /// title's place stands, and past 1 it goes beyond, the other way.
        public func letters(at moment: Moment) throws(Picture.Text.Error) -> [Letter] {
            let text = try text
            guard !style.runs.isEmpty else { return [] }
            let cap = try Picture.Text.Metrics(font: style.font, size: style.size).cap
            let start = place[0] - anchor.indent(of: 0, in: text.width)
            let baseline = place[1]
            var ends: [Int] = []
            var end = 0
            for run in runs {
                end += run.unicodeScalars.count
                ends.append(end)
            }
            var letters: [Letter] = []
            for (position, (glyph, entered)) in zip(text.glyphs, moment.letters).enumerated() where entered > 0 {
                guard let box = glyph.path.boundingBox else { continue }
                let run = ends.firstIndex { position < $0 } ?? Swift.max(runs.count - 1, 0)
                let look = style.runs[run % style.runs.count]
                let middle = (x: (box.llx.underlying + box.urx.underlying) / 2, y: -cap / 2)
                let due = 1 - entered
                let transform = Picture.Transform.translation(x: start + middle.x, y: baseline + middle.y + due * look.rise * style.size)
                    .multiplied(by: .scale(Swift.max(1 + look.grow * due, 0), about: Picture.Plane.Point<2>([0.0, 0.0])))
                    .multiplied(by: .translation(x: -middle.x, y: -middle.y))
                letters.append(Letter(glyph: glyph, transform: transform, color: look.color, opacity: Swift.min(Swift.max(look.fade * entered, 0), 1)))
            }
            return letters
        }
    }
#endif
