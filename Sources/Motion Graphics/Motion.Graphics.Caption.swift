#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// One transcript line on a plate, standing at a place in the frame: centred on the place across, its last
        /// baseline through it, so a line low and centred in the frame reads over whatever plays behind it.
        public struct Caption: Sendable {
            public var line: Transcript.Line

            /// The middle of the last row's baseline.
            public var place: Picture.Plane.Point<2>

            public var style: Style

            public init(_ line: Transcript.Line, at place: Picture.Plane.Point<2>, style: Style) {
                self.line = line
                self.place = place
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Caption {
        /// The line as a transcript of one line, its mark where the caption puts it.
        public var transcript: Motion.Graphics.Transcript {
            get throws(Picture.Text.Error) {
                let alone = Motion.Graphics.Transcript([line], at: place, style: style.transcript)
                let rows = Double(Int(clamping: alone.rows))
                let origin = Picture.Plane.Point<2>([place[0] - (try alone.width) / 2, place[1] - Swift.max(rows - 1, 0) * style.transcript.leading])
                return Motion.Graphics.Transcript([line], at: origin, style: style.transcript)
            }
        }

        /// The plate at rest: around the line with all its characters, from the plate's ascent above the first
        /// baseline to its descent below the last, padded by its insets.
        public var plate: Picture.Plane.Rectangle {
            get throws(Picture.Text.Error) {
                let set = try transcript
                let plate = style.plate
                let rows = Double(Int(clamping: set.rows))
                let last = set.origin[1] + Swift.max(rows - 1, 0) * style.transcript.leading
                return Picture.Plane.Rectangle(
                    llx: .init(set.origin[0] - plate.horizontal),
                    lly: .init(set.origin[1] - plate.ascent - plate.vertical),
                    urx: .init(set.origin[0] + (try set.width) + plate.horizontal),
                    ury: .init(last + plate.descent + plate.vertical)
                )
            }
        }
    }
#endif
