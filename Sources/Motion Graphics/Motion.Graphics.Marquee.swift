#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A wall of moving type: rows of words repeated end to end across a region, one row a pitch below the
        /// next until the region is full, sliding in turn left and right as the moment travels, each row filled or
        /// outlined as the style's faces say. The lines are set once, when the marquee is made.
        public struct Marquee: Sendable {
            /// The words of the rows: row i repeats the `i mod n`th of the n lines.
            public let lines: [Swift.String]
            public var region: Picture.Plane.Rectangle
            public let style: Style
            /// Each line set in the ink.
            let texts: [Picture.Text]
            /// The ink's cap height.
            let cap: Double

            /// A marquee, its lines set once: it fails as `Picture.Text` does for a line in the ink.
            public init(_ lines: [Swift.String], in region: Picture.Plane.Rectangle, style: Style) throws(Picture.Text.Error) {
                self.lines = lines
                self.region = region
                self.style = style
                var texts: [Picture.Text] = []
                for line in lines {
                    texts.append(try style.ink.text(line))
                }
                self.texts = texts
                self.cap = try Picture.Text.Metrics(font: style.ink.font, size: style.ink.size).cap
            }
        }
    }

    extension Motion.Graphics.Marquee {
        /// How many rows fill the region: one for each band a pitch tall that begins above its bottom, the first
        /// at its top. With no lines or no pitch, none.
        public var rows: Cardinal {
            let tall = region.ury.underlying - region.lly.underlying
            guard !lines.isEmpty, style.pitch > 0, tall > 0 else { return .zero }
            return Cardinal(UInt((tall / style.pitch).rounded(.up)))
        }

        /// The words of a row as they were set in the ink.
        func set(row: Ordinal) -> Picture.Text {
            texts[Int(bitPattern: row) % texts.count]
        }

        /// The distance from one copy's start to the next in a row: its words' width and the gap.
        public func unit(row: Ordinal) -> Double {
            set(row: row).width + style.gap
        }

        /// How far left of the region's left edge the first copy of a row starts when the wall has travelled a
        /// distance: from 0 up to the unit, not including it, so it wraps every unit and the copies always cover
        /// the row. The row's own travel is the wall's plus its start in the style; even rows, the first
        /// included, slide left as it grows and odd rows slide right.
        public func offset(row: Ordinal, travel: Double) -> Double {
            let unit = unit(row: row)
            let index = Int(bitPattern: row)
            let own = travel + (style.starts.isEmpty ? 0 : style.starts[index % style.starts.count])
            guard unit > 0, own.isFinite else { return 0 }
            let moved = index % 2 == 0 ? own : -own
            let wrapped = moved - (moved / unit).rounded(.down) * unit
            return wrapped < unit ? wrapped : 0
        }
    }
#endif
