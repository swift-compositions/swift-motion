#if Graphics
    public import Motion

    extension Motion.Graphics.Caption {
        /// A caption at an instant: how much of it shows, which is how it arrives and leaves; how far it has risen
        /// into place, 1 at rest, beyond 1 for an overshoot; and its line's moment.
        public struct Moment: Sendable, Hashable {
            public var shown: Double
            public var risen: Double
            public var line: Motion.Graphics.Transcript.Line.Moment

            public init(shown: Double, risen: Double = 1, line: Motion.Graphics.Transcript.Line.Moment = .resting) {
                self.shown = shown
                self.risen = risen
                self.line = line
            }
        }
    }

    extension Motion.Graphics.Caption.Moment {
        /// Nothing of the caption.
        public static let hidden = Self(shown: 0, risen: 0, line: .hidden)

        /// The caption in place with its whole line.
        public static let resting = Self(shown: 1)
    }
#endif
