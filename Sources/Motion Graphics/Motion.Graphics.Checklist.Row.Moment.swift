#if Graphics
    public import Motion

    extension Motion.Graphics.Checklist.Row {
        /// A row at an instant: its box's moment, how far its name has slid in, 0 to 1, and the share of its
        /// tag's characters typed, 0 to 1. A row whose box has not begun to spring in is hidden.
        public struct Moment: Sendable, Hashable {
            public var box: Motion.Graphics.Checkbox.Moment
            public var named: Double
            public var tagged: Double

            public init(box: Motion.Graphics.Checkbox.Moment, named: Double, tagged: Double = 0) {
                self.box = box
                self.named = named
                self.tagged = tagged
            }
        }
    }

    extension Motion.Graphics.Checklist.Row.Moment {
        /// Nothing of the row.
        public static let hidden = Self(box: .hidden, named: 0)

        /// The row done: its box ticked, its name in place and its tag typed.
        public static let resting = Self(box: .ticked, named: 1, tagged: 1)
    }
#endif
