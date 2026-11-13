#if Graphics
    public import Motion

    extension Motion.Graphics.Transcript.Line {
        /// A line at an instant.
        public struct Moment: Sendable, Hashable {
            /// How much of the line shows, 0 none, 1 all: it fades the mark, the words and the caret alike.
            public var shown: Double

            /// How much of the mark shows, 0 to 1, while its cells are kept.
            public var marked: Double

            /// The share of the characters that stand, 0 to 1: floor(share · characters) of them.
            public var typed: Double

            /// How much of the caret shows after the last standing character, 0 to 1.
            public var caret: Double

            public init(shown: Double = 1, marked: Double = 1, typed: Double = 1, caret: Double = 0) {
                self.shown = shown
                self.marked = marked
                self.typed = typed
                self.caret = caret
            }
        }
    }

    extension Motion.Graphics.Transcript.Line.Moment {
        /// Nothing of the line.
        public static let hidden = Self(shown: 0, marked: 0, typed: 0, caret: 0)

        /// The whole line, its mark and every character, without a caret.
        public static let resting = Self()
    }
#endif
