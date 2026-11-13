#if Graphics
    public import Motion

    extension Motion.Graphics.Checkbox {
        /// A box at an instant: how far it has sprung in, 1 at rest and beyond 1 in an overshoot; how far its
        /// fill has grown; how much of the tick is drawn; and the flash of its landing, 1 falling to 0.
        public struct Moment: Sendable, Hashable {
            public var box: Double
            public var filled: Double
            public var stroke: Double
            public var flash: Double

            public init(box: Double, filled: Double = 0, stroke: Double = 0, flash: Double = 0) {
                self.box = box
                self.filled = filled
                self.stroke = stroke
                self.flash = flash
            }
        }
    }

    extension Motion.Graphics.Checkbox.Moment {
        /// No box.
        public static let hidden = Self(box: 0)

        /// An empty box at rest.
        public static let resting = Self(box: 1)

        /// A ticked box at rest.
        public static let ticked = Self(box: 1, filled: 1, stroke: 1)
    }
#endif
