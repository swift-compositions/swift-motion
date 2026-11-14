#if Graphics
    public import Motion

    extension Motion.Graphics.Transcript {
        /// A transcript at an instant: a moment for each line in order. A line without one is hidden, though it
        /// keeps its rows.
        public struct Moment: Sendable, Hashable {
            public var lines: [Line.Moment]

            public init(_ lines: [Line.Moment]) {
                self.lines = lines
            }
        }
    }

    extension Motion.Graphics.Transcript.Moment {
        /// No lines.
        public static let hidden = Self([])

        /// Some lines whole, without a caret.
        public static func resting(_ lines: Cardinal) -> Self {
            Self(Swift.Array(repeating: .resting, count: Int(clamping: lines)))
        }
    }
#endif
