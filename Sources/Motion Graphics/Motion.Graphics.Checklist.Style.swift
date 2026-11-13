#if Graphics
    public import Motion

    extension Motion.Graphics.Checklist {
        /// A checklist's look: its heading, its statement, its rows and its plate.
        public struct Style: Sendable {
            public var heading: Heading
            public var statement: Statement
            public var row: Row.Style
            public var plate: Plate

            public init(heading: Heading, statement: Statement, row: Row.Style, plate: Plate) {
                self.heading = heading
                self.statement = statement
                self.row = row
                self.plate = plate
            }
        }
    }
#endif
