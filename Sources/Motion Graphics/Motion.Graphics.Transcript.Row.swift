#if Graphics
    import Motion
    import Picture

    extension Motion.Graphics.Transcript {
        /// One row of a line as it is set: how many of the line's glyphs come before it, its words set in the
        /// line's ink, and each glyph's outline where the row sets it.
        struct Row: Sendable {
            let start: Int
            let text: Picture.Text
            let paths: [Picture.Plane.Path]

            init(start: Int, text: Picture.Text) {
                self.start = start
                self.text = text
                self.paths = text.glyphs.map(\.path)
            }
        }
    }

    extension Motion.Graphics.Transcript.Row {
        /// How many of the row's glyphs stand when a number of the line's glyphs do.
        func standing(_ count: Int) -> Int {
            Swift.min(Swift.max(count - start, 0), paths.count)
        }

        /// The outline of the row's first glyphs: its text's path when all of them stand.
        func path(standing count: Int) -> Picture.Plane.Path {
            count >= paths.count ? text.path : Picture.Plane.Path(subpaths: paths.prefix(count).flatMap(\.subpaths))
        }
    }
#endif
