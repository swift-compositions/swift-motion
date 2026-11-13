#if Picture
    public import Motion

    extension Motion.Reel {
        /// What to print of some frames of a reel to look at them without watching them: contact sheets, and
        /// stills, which are frames at full size. Frames are counted among the frames printed: for one part,
        /// the part's own frames.
        public struct Proof: Sendable, Equatable {
            public let sheets: [Sheet]
            public let stills: [Ordinal]

            public init(sheets: [Sheet] = [], stills: [Ordinal] = []) {
                self.sheets = sheets
                self.stills = stills
            }
        }
    }

    extension Motion.Reel.Proof {
        /// A proof of a run of frames that shows all of it at a glance: one sheet, named by nothing, of every
        /// frame or every so many frames, as few as keep it to at most sixty, ten to a row; and the first, the
        /// middle and the last frame as stills. No frames give an empty proof.
        public static func overview(of frames: Cardinal) -> Self {
            let count = Int(clamping: frames)
            guard count > 0 else { return Self() }
            let step = (count + 59) / 60
            let shown = stride(from: 0, to: count, by: step).map { Ordinal(UInt($0)) }
            let stills = Array(Set([0, count / 2, count - 1])).sorted().map { Ordinal(UInt($0)) }
            return Self(sheets: [Motion.Reel.Sheet(frames: shown, columns: 10)], stills: stills)
        }
    }
#endif
