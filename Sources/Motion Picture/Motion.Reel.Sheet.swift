#if Picture
    public import Motion
    public import Picture

    extension Motion.Reel {
        /// A contact sheet to print: a name, the frames on it, how many to a row, the gap between them and the
        /// colour of the gap. Frames are counted among the frames a proof is printed of.
        public struct Sheet: Sendable, Equatable {
            public let name: String
            public let frames: [Ordinal]
            public let columns: Cardinal
            public let gap: Cardinal
            public let fill: Picture::Picture.Color

            /// Without a gap there are twelve pixels between the frames, in a dark grey.
            public init(
                _ name: String = "",
                frames: [Ordinal],
                columns: Cardinal,
                gap: Cardinal = 12,
                fill: Picture::Picture.Color = Picture::Picture.Color(gray: 0.12)
            ) {
                self.name = name
                self.frames = frames
                self.columns = columns
                self.gap = gap
                self.fill = fill
            }
        }
    }
#endif
