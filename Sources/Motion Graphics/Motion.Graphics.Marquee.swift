#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A wall of moving type: rows of words repeated end to end across a region, one row a pitch below the
        /// next until the region is full, sliding in turn left and right as the moment travels, each row filled or
        /// outlined as the style's faces say.
        public struct Marquee: Sendable {
            /// The words of the rows: row i repeats the `i mod n`th of the n lines.
            public var lines: [Swift.String]
            public var region: Picture.Plane.Rectangle
            public var style: Style

            public init(_ lines: [Swift.String], in region: Picture.Plane.Rectangle, style: Style) {
                self.lines = lines
                self.region = region
                self.style = style
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

        /// The words of a row set in the ink.
        func set(row: Ordinal) throws(Picture.Text.Error) -> Picture.Text {
            try style.ink.text(lines[Int(bitPattern: row) % lines.count])
        }

        /// The distance from one copy's start to the next in a row: its words' width and the gap.
        public func unit(row: Ordinal) throws(Picture.Text.Error) -> Double {
            try set(row: row).width + style.gap
        }

        /// How far left of the region's left edge the first copy of a row starts when the wall has travelled a
        /// distance: from 0 up to the unit, not including it, so it wraps every unit and the copies always cover
        /// the row. Even rows, the first included, slide left as the travel grows and odd rows slide right.
        public func offset(row: Ordinal, travel: Double) throws(Picture.Text.Error) -> Double {
            let unit = try unit(row: row)
            guard unit > 0, travel.isFinite else { return 0 }
            let moved = Int(bitPattern: row) % 2 == 0 ? travel : -travel
            let wrapped = moved - (moved / unit).rounded(.down) * unit
            return wrapped < unit ? wrapped : 0
        }
    }
#endif
