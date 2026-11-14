#if Graphics
    public import Motion

    extension Motion.Graphics.Checklist {
        /// A checklist's look: its heading, its statement, its rows, its plate, and the share of its size the
        /// plate grows by as it settles.
        public struct Style: Sendable {
            public var heading: Heading

            public var statement: Statement

            public var row: Row.Style

            public var plate: Motion.Graphics.Plate

            public var settle: Double

            public init(heading: Heading, statement: Statement, row: Row.Style, plate: Motion.Graphics.Plate, settle: Double) {
                self.heading = heading
                self.statement = statement
                self.row = row
                self.plate = plate
                self.settle = settle
            }
        }
    }
#endif
