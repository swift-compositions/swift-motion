#if Graphics
    public import Motion

    extension Motion.Graphics.Checklist {
        /// An item: its name beside the box, and the tag typed at the row's right end once it is ticked.
        public struct Item: Sendable, Hashable {
            public var name: Swift.String
            public var tag: Swift.String

            public init(_ name: Swift.String, tag: Swift.String = "") {
                self.name = name
                self.tag = tag
            }
        }
    }
#endif
