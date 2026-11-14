#if Graphics
    public import Motion

    extension Motion.Graphics.Twinkle {
        /// One ray of a star: a line of light through its center at an angle, in radians clockwise on a screen
        /// from the right, as long as `length` from the center either way and `width` thick at full shine.
        public struct Ray: Sendable, Hashable {
            public var angle: Double
            public var length: Double
            public var width: Double

            public init(angle: Double, length: Double, width: Double) {
                self.angle = angle
                self.length = length
                self.width = width
            }
        }
    }
#endif
