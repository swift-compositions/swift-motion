#if Picture
    public import Byte
    public import Motion

    extension Motion.Reel {
        /// A proof printed: each sheet as a PNG under its name, and each still as a PNG under its frame.
        public struct Prints: Sendable, Equatable {
            public let sheets: [String: [Byte]]
            public let stills: [Ordinal: [Byte]]

            public init(sheets: [String: [Byte]], stills: [Ordinal: [Byte]]) {
                self.sheets = sheets
                self.stills = stills
            }
        }
    }
#endif
