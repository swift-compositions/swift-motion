#if Graphics
    public import Motion

    extension Motion.Graphics.Checklist.Style {
        /// The statement: its ink, how far right of the left edge it stands, how far below its baseline it starts
        /// its rise, and its slot about its baseline, in sizes of its ink, across the plate.
        public struct Statement: Sendable {
            public var ink: Motion.Graphics.Ink

            public var indent: Double

            public var rise: Double

            public var slot: Motion.Graphics.Slot

            public init(ink: Motion.Graphics.Ink, indent: Double, rise: Double, slot: Motion.Graphics.Slot) {
                self.ink = ink
                self.indent = indent
                self.rise = rise
                self.slot = slot
            }
        }
    }
#endif
