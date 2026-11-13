#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Checklist {
        /// Where a checklist stands: the left edge its heading, statement and boxes start from, the right edge its
        /// tags end at, the heading's, the statement's and the first row's baselines, the pitch from one row to the
        /// next, and the plate's frame at rest.
        public struct Layout: Sendable, Hashable {
            public var left: Double
            public var right: Double
            public var heading: Double
            public var statement: Double
            public var first: Double
            public var pitch: Double
            public var plate: Picture.Plane.Rectangle

            public init(
                left: Double,
                right: Double,
                heading: Double,
                statement: Double,
                first: Double,
                pitch: Double,
                plate: Picture.Plane.Rectangle
            ) {
                self.left = left
                self.right = right
                self.heading = heading
                self.statement = statement
                self.first = first
                self.pitch = pitch
                self.plate = plate
            }
        }
    }
#endif
