#if Graphics
    import Motion
    import Picture

    extension Motion.Graphics.Transcript {
        /// A line as it is set: its mark set in the mark's ink, the ink its words take, how many glyphs its words
        /// have, the cells its mark takes, its rows each set in that ink, and its widest row's cells, its mark's
        /// included.
        struct Setting: Sendable {
            let mark: Picture.Text?
            let ink: Motion.Graphics.Ink
            let length: Int
            let lead: Int
            let rows: [Row]
            let columns: Int
        }
    }

    extension Motion.Graphics.Transcript.Setting {
        /// A line set in a style: its mark in the mark's ink, and its words, row by row, in the typed ink after a
        /// prompt and in the said ink otherwise.
        init(_ line: Motion.Graphics.Transcript.Line, style: Motion.Graphics.Transcript.Style) throws(Picture.Text.Error) {
            switch line.mark {
            case .prompt(let word):
                self.mark = try style.mark.text(word)
                self.ink = style.typed
            case .label(let word, _):
                self.mark = try style.mark.text(word)
                self.ink = style.said
            case .plain:
                self.mark = nil
                self.ink = style.said
            }
            self.length = Int(clamping: line.length)
            self.lead = line.lead
            var rows: [Motion.Graphics.Transcript.Row] = []
            for (start, words) in line.rows(within: style.columns) {
                rows.append(Motion.Graphics.Transcript.Row(start: start, text: try ink.text(words)))
            }
            self.rows = rows
            self.columns = lead + (rows.map(\.paths.count).max() ?? 0)
        }
    }
#endif
