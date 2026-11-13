#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// Lines of a terminal, set in a monospace one under another: lines typed after a prompt mark, with a
        /// block caret where the typing stands, and the answers, plain or as diagnostics that begin with a label
        /// in a colour of their own.
        ///
        /// Every character takes one cell of the typed ink's advance. A line's mark and the space after it take
        /// the first cells, and every row of the line starts after them, so a diagnostic's further rows stand
        /// under its first word. A line feed starts a new row, and with `columns` in the style a row also breaks
        /// before a word that would end beyond them.
        public struct Transcript: Sendable {
            public var lines: [Line]

            /// The start of the first line's baseline: where the marks stand.
            public var origin: Picture.Plane.Point<2>

            public var style: Style

            public init(_ lines: [Line], at origin: Picture.Plane.Point<2>, style: Style) {
                self.lines = lines
                self.origin = origin
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Transcript {
        /// How many rows the lines take.
        public var rows: Cardinal {
            Cardinal(UInt(lines.reduce(0) { $0 + $1.rows(within: style.columns).count }))
        }

        /// The width of the widest line with all its characters, its mark included.
        public var width: Double {
            get throws(Picture.Text.Error) {
                let widest = lines.map { $0.columns(within: style.columns) }.max() ?? 0
                return Double(widest) * (try style.advance)
            }
        }

        /// The baseline of each line's first row, from the origin down by the leading for each row before it.
        var baselines: [Double] {
            let before = lines.reduce(into: [0]) { rows, line in rows.append((rows.last ?? 0) + line.rows(within: style.columns).count) }
            return before.dropLast().map { origin[1] + Double($0) * style.leading }
        }
    }
#endif
