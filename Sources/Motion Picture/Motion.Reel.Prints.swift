#if Picture
    public import Byte
    public import Motion

    extension Motion.Reel {
        /// A proof printed: each sheet as a PNG under its name, each still as a PNG under its frame, and each
        /// picture as a PNG under its name.
        public struct Prints: Sendable, Equatable {
            public let sheets: [String: [Byte]]
            public let stills: [Ordinal: [Byte]]
            public let pictures: [String: [Byte]]

            public init(sheets: [String: [Byte]], stills: [Ordinal: [Byte]], pictures: [String: [Byte]] = [:]) {
                self.sheets = sheets
                self.stills = stills
                self.pictures = pictures
            }
        }
    }
#endif
