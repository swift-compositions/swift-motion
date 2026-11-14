#if Graphics
    public import Motion
    import Picture

    extension Motion.Graphics.Transcript {
        /// A transcript's look: the inks of what is typed, what is said and the marks, the distance between
        /// baselines, the caret, and where rows break.
        public struct Style: Sendable {
            /// The words of a line after a prompt. Its font's advance at its size is every cell's width.
            public var typed: Motion.Graphics.Ink

            /// The words of a diagnostic or a plain line.
            public var said: Motion.Graphics.Ink

            /// A prompt mark, and the font and size of a label.
            public var mark: Motion.Graphics.Ink

            /// The distance from one baseline to the next.
            public var leading: Double

            public var caret: Caret

            /// The cells a row may take, its mark's included, or nil for rows that break only at line feeds.
            public var columns: Cardinal?

            public init(
                typed: Motion.Graphics.Ink,
                said: Motion.Graphics.Ink,
                mark: Motion.Graphics.Ink,
                leading: Double,
                caret: Caret,
                columns: Cardinal?
            ) {
                self.typed = typed
                self.said = said
                self.mark = mark
                self.leading = leading
                self.caret = caret
                self.columns = columns
            }
        }
    }

    extension Motion.Graphics.Transcript.Style {
        /// A cell's width: the typed font's pitch at its size when the font is fixed pitch, and otherwise the
        /// advance of its capital M.
        public var advance: Double {
            get throws(Typesetting.Error) {
                let metrics = try Typesetting.Metrics(font: typed.font, size: typed.size)
                if let pitch = metrics.pitch { return pitch }
                return try typed.text("M").glyphs.first?.advance ?? metrics.figure
            }
        }
    }
#endif
