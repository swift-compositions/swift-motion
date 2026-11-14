#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// Lines of a terminal, set in a monospace one under another: lines typed after a prompt mark, with a
        /// block caret where the typing stands, and the answers, plain or as diagnostics that begin with a label
        /// in a colour of their own.
        ///
        /// Every glyph takes one cell of the typed ink's advance. A line's mark and the space after it take the
        /// first cells, and every row of the line starts after them, so a diagnostic's further rows stand under
        /// its first word. A line feed starts a new row, and with `columns` in the style a row also breaks before
        /// a word that would end beyond them. The lines are set once, when the transcript is made.
        public struct Transcript: Sendable {
            public let lines: [Line]
            /// The start of the first line's baseline: where the marks stand.
            public var place: Picture.Plane.Point<2>
            public let style: Style
            /// A cell's width: the style's `advance`.
            public let advance: Double
            /// Each line as it is set.
            let settings: [Setting]

            /// A transcript, its lines set once: it fails as `Picture.Text` does for a mark or a row in its ink.
            public init(_ lines: [Line], at place: Picture.Plane.Point<2>, style: Style) throws(Picture.Text.Error) {
                self.lines = lines
                self.place = place
                self.style = style
                self.advance = try style.advance
                var settings: [Setting] = []
                for line in lines {
                    settings.append(try Setting(line, style: style))
                }
                self.settings = settings
            }
        }
    }

    extension Motion.Graphics.Transcript {
        /// How many rows the lines take.
        public var rows: Cardinal {
            Cardinal(UInt(settings.reduce(0) { $0 + $1.rows.count }))
        }

        /// The width of the widest line with all its glyphs, its mark included.
        public var width: Double {
            Double(settings.map(\.columns).max() ?? 0) * advance
        }

        /// The baseline of each line's first row, from the place down by the leading for each row before it.
        var baselines: [Double] {
            let before = settings.reduce(into: [0]) { rows, setting in rows.append((rows.last ?? 0) + setting.rows.count) }
            return before.dropLast().map { place[1] + Double($0) * style.leading }
        }
    }
#endif
