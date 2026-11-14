#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// One transcript line on a plate, standing at a place in the frame: its last baseline through the place,
        /// which is the line's left end, its middle or its right end as `anchor` says, so a line low and centered
        /// in the frame reads over whatever plays behind it. The line is set once, when the caption is made.
        public struct Caption: Sendable {
            public let line: Transcript.Line
            /// A point of the last row's baseline: the line's left end, its middle or its right end, as `anchor`
            /// says.
            public var place: Picture.Plane.Point<2>
            public var anchor: Picture.Text.Alignment
            public let style: Style
            /// The line set as a transcript of one line, from the origin.
            let set: Transcript

            /// A caption, its line set once: it fails as `Transcript` does.
            public init(
                _ line: Transcript.Line,
                at place: Picture.Plane.Point<2>,
                anchor: Picture.Text.Alignment,
                style: Style
            ) throws(Picture.Text.Error) {
                self.line = line
                self.place = place
                self.anchor = anchor
                self.style = style
                self.set = try Transcript([line], at: Picture.Plane.Point<2>([0, 0]), style: style.transcript)
            }
        }
    }

    extension Motion.Graphics.Caption {
        /// The line as a transcript of one line, its mark where the caption puts it.
        public var transcript: Motion.Graphics.Transcript {
            var placed = set
            let rows = Double(Int(clamping: set.rows))
            placed.place = Picture.Plane.Point<2>([place[0] - anchor.indent(of: 0, in: set.width), place[1] - Swift.max(rows - 1, 0) * style.transcript.leading])
            return placed
        }

        /// The plate at rest: around the line with all its glyphs, from the style's ascent above the first
        /// baseline to its descent below the last, padded by its insets.
        public var plate: Picture.Plane.Rectangle {
            let set = transcript
            let rows = Double(Int(clamping: set.rows))
            let last = set.place[1] + Swift.max(rows - 1, 0) * style.transcript.leading
            return Picture.Plane.Rectangle(
                llx: .init(set.place[0] - style.horizontal),
                lly: .init(set.place[1] - style.ascent - style.vertical),
                urx: .init(set.place[0] + set.width + style.horizontal),
                ury: .init(last + style.descent + style.vertical)
            )
        }
    }
#endif
