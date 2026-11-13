#if Graphics
    public import Motion

    extension Motion.Graphics.Spinner {
        /// A spinner at an instant: how much of it shows, 0 to 1; how far it has turned, in turns, clockwise on a
        /// screen from the top; how much of the ring the arc fills, 0 to 1; and the flash of its landing, 1
        /// falling to 0.
        public struct Moment: Sendable, Hashable {
            public var shown: Double
            public var turn: Double
            public var filled: Double
            public var flash: Double

            public init(shown: Double = 1, turn: Double = 0, filled: Double, flash: Double = 0) {
                self.shown = shown
                self.turn = turn
                self.filled = filled
                self.flash = flash
            }
        }
    }

    extension Motion.Graphics.Spinner.Moment {
        /// No spinner.
        public static let hidden = Self(shown: 0, filled: 0)

        /// The whole ring, shown.
        public static let resting = Self(filled: 1)
    }
#endif
