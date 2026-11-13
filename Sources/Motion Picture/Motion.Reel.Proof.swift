#if Picture
    public import Motion
    public import Picture

    extension Motion.Reel {
        /// What to print of some frames of a reel to look at them without watching them: contact sheets, stills,
        /// which are frames at full size, and pictures that are no frame of the reel, drawn at its size over its
        /// background, such as a component shown alone. Frames are counted among the frames printed: for one part,
        /// the part's own frames; for the whole reel, from the reel's start.
        public struct Proof: Sendable, Equatable {
            public let sheets: [Sheet]
            public let stills: [Ordinal]
            /// Pictures to print under their names.
            public let pictures: [String: Picture::Picture]

            public init(sheets: [Sheet] = [], stills: [Ordinal] = [], pictures: [String: Picture::Picture] = [:]) {
                self.sheets = sheets
                self.stills = stills
                self.pictures = pictures
            }
        }
    }

    extension Motion.Reel.Proof {
        /// A proof of a run of frames that shows all of it at a glance: one sheet, named by nothing, of every
        /// frame or every so many frames, as few as keep it to at most sixty, ten to a row; and the first, the
        /// middle and the last frame as stills. No frames give an empty proof.
        public static func overview(of frames: Cardinal) -> Self {
            overview(of: (0..<Int(clamping: frames)).map { Ordinal(UInt($0)) })
        }

        /// `overview(of:)` of some frames rather than a run from zero, in the order given: of the frames of a layer,
        /// say, in a proof of the whole reel.
        public static func overview(of frames: [Ordinal]) -> Self {
            let count = frames.count
            guard count > 0 else { return Self() }
            let step = (count + 59) / 60
            let shown = stride(from: 0, to: count, by: step).map { frames[$0] }
            let stills = Array(Set([0, count / 2, count - 1])).sorted().map { frames[$0] }
            return Self(sheets: [Motion.Reel.Sheet(frames: shown, columns: 10)], stills: stills)
        }
    }
#endif
