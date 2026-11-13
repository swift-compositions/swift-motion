#if Graphics
    public import Motion

    extension Motion.Graphics.Marquee {
        /// A marquee's look: the ink of its words, the faces its rows take in turn, the distance from one row's
        /// band to the next, the gap between one copy of a row's words and the next, how far a row rises into
        /// place, the window it shows through, and where each row starts along its travel.
        public struct Style: Sendable {
            public var ink: Motion.Graphics.Ink

            /// Row i takes the `i mod n`th of the n faces; with none, every row is filled.
            public var faces: [Face]
            public var pitch: Double
            public var gap: Double

            /// How far below its place a row starts as it rises; nil for the pitch.
            public var rise: Double?

            /// The window a row shows through; nil for its band, a pitch tall from its top.
            public var slot: Slot?

            /// How far along its own travel row i starts, the `i mod n`th of the n starts; with none, every row
            /// starts at the shared travel.
            public var starts: [Double]

            public init(
                ink: Motion.Graphics.Ink,
                faces: [Face],
                pitch: Double,
                gap: Double,
                rise: Double? = nil,
                slot: Slot? = nil,
                starts: [Double] = []
            ) {
                self.ink = ink
                self.faces = faces
                self.pitch = pitch
                self.gap = gap
                self.rise = rise
                self.slot = slot
                self.starts = starts
            }
        }
    }
#endif
