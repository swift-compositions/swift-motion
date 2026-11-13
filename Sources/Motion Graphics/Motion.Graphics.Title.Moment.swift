#if Graphics
    public import Motion

    extension Motion.Graphics.Title {
        /// A title at an instant: for each of its glyphs in order, one for each unicode scalar of its runs, how far
        /// it has entered, 0 to 1 and past 1 in a spring's overshoot; a glyph without one is hidden.
        public struct Moment: Sendable, Hashable {
            public var letters: [Double]

            public init(_ letters: [Double]) {
                self.letters = letters
            }
        }
    }

    extension Motion.Graphics.Title.Moment {
        /// No letters.
        public static let hidden = Self([])

        /// Some letters in place.
        public static func resting(_ letters: Cardinal) -> Self {
            Self(Swift.Array(repeating: 1, count: Int(clamping: letters)))
        }
    }
#endif
