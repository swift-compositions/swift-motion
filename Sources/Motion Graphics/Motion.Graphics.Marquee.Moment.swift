#if Graphics
    public import Motion

    extension Motion.Graphics.Marquee {
        /// A marquee at an instant: how far its rows have travelled, in picture units, and how far each row has
        /// risen into its band, 0 to 1, a row without one hidden.
        public struct Moment: Sendable, Hashable {
            public var travel: Double
            public var rows: [Double]

            public init(travel: Double, rows: [Double]) {
                self.travel = travel
                self.rows = rows
            }
        }
    }

    extension Motion.Graphics.Marquee.Moment {
        /// No rows.
        public static let hidden = Self(travel: 0, rows: [])

        /// Some rows risen and standing at their start.
        public static func resting(_ rows: Cardinal) -> Self {
            Self(travel: 0, rows: Swift.Array(repeating: 1, count: Int(clamping: rows)))
        }
    }
#endif
