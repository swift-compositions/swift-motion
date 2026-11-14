#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// One transcript line on a plate, standing at a place in the frame: centred on the place across, its last
        /// baseline through it, so a line low and centred in the frame reads over whatever plays behind it. The
        /// line is set once, when the caption is made.
        public struct Caption: Sendable {
            public let line: Transcript.Line
            /// The middle of the last row's baseline.
            public var place: Picture.Plane.Point<2>
            public let style: Style
            /// The line set as a transcript of one line, from the origin.
            let set: Transcript

            /// A caption, its line set once: it fails as `Transcript` does.
            public init(_ line: Transcript.Line, at place: Picture.Plane.Point<2>, style: Style) throws(Picture.Text.Error) {
                self.line = line
                self.place = place
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
            placed.origin = Picture.Plane.Point<2>([place[0] - set.width / 2, place[1] - Swift.max(rows - 1, 0) * style.transcript.leading])
            return placed
        }

        /// The plate at rest: around the line with all its glyphs, from the plate's ascent above the first
        /// baseline to its descent below the last, padded by its insets.
        public var plate: Picture.Plane.Rectangle {
            let set = transcript
            let plate = style.plate
            let rows = Double(Int(clamping: set.rows))
            let last = set.origin[1] + Swift.max(rows - 1, 0) * style.transcript.leading
            return Picture.Plane.Rectangle(
                llx: .init(set.origin[0] - plate.horizontal),
                lly: .init(set.origin[1] - plate.ascent - plate.vertical),
                urx: .init(set.origin[0] + set.width + plate.horizontal),
                ury: .init(last + plate.descent + plate.vertical)
            )
        }
    }
#endif
