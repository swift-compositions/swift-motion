#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Readout.Style {
        /// The bar: its top below the plate's top, its height, and the colour of the track the share fills.
        public struct Bar: Sendable, Hashable {
            public var top: Double
            public var height: Double
            public var track: Picture.Color

            public init(top: Double, height: Double, track: Picture.Color) {
                self.top = top
                self.height = height
                self.track = track
            }
        }
    }
#endif
