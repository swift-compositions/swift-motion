extension Motion {
    /// One pixel of a frame: blue, green, red and alpha, eight bits each, sRGB-encoded, colour already multiplied by alpha.
    public struct Pixel: Hashable, Sendable {
        public let blue: UInt8
        public let green: UInt8
        public let red: UInt8
        public let alpha: UInt8

        /// Nil when a colour channel exceeds the alpha, which a premultiplied pixel never does.
        public init?(blue: UInt8, green: UInt8, red: UInt8, alpha: UInt8) {
            guard blue <= alpha, green <= alpha, red <= alpha else { return nil }
            self.blue = blue
            self.green = green
            self.red = red
            self.alpha = alpha
        }
    }
}
