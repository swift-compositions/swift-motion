#if Graphics
    public import Motion

    extension Motion.Graphics.Checklist {
        /// A checklist at an instant: how much of the plate shows and how far it has settled, how far the heading
        /// has slid in and turned to its second colour, how far the statement has risen, and a moment for each row
        /// in order, a row without one hidden. Each is 0 to 1; a settle may overshoot.
        public struct Moment: Sendable, Hashable {
            public var shown: Double
            public var settled: Double
            public var headed: Double
            public var toned: Double
            public var stated: Double
            public var rows: [Row.Moment]

            public init(shown: Double, settled: Double, headed: Double, toned: Double, stated: Double, rows: [Row.Moment]) {
                self.shown = shown
                self.settled = settled
                self.headed = headed
                self.toned = toned
                self.stated = stated
                self.rows = rows
            }
        }
    }

    extension Motion.Graphics.Checklist.Moment {
        /// Nothing of the checklist.
        public static let hidden = Self(shown: 0, settled: 0, headed: 0, toned: 0, stated: 0, rows: [])

        /// The checklist at rest with some rows ticked, named and tagged.
        public static func resting(_ rows: Cardinal) -> Self {
            Self(shown: 1, settled: 1, headed: 1, toned: 0, stated: 1, rows: Swift.Array(repeating: .resting, count: Int(clamping: rows)))
        }
    }
#endif
