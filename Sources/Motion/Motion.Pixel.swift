import IEC_61966

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

extension Motion.Pixel {
    /// The pixel nearest to a colour in linear light whose red, green and blue are already multiplied
    /// by alpha, which is how a picture is drawn and mixed.
    ///
    /// Alpha is held to 0…1. Each colour is divided by it, held to 0…1, put through the sRGB transfer
    /// function and multiplied by alpha again, since a frame's colours are multiplied in their encoded
    /// form. Each of the four is then one of 256 levels, rounded to the nearest, halves up. Light
    /// brighter than white is white, and anything that is not a number is nothing. No colour comes out
    /// above its alpha, so the result is always a pixel.
    public init(linear red: Float, green: Float, blue: Float, alpha: Float) {
        let alpha = Self.unit(alpha)
        self.blue = Self.level(Self.encoded(blue, under: alpha) * alpha)
        self.green = Self.level(Self.encoded(green, under: alpha) * alpha)
        self.red = Self.level(Self.encoded(red, under: alpha) * alpha)
        self.alpha = Self.level(alpha)
    }

    /// A value held to 0…1, with anything that is not a number as 0.
    static func unit(_ value: Float) -> Float {
        value > 0 ? Swift.min(value, 1) : 0
    }

    /// A value of 0…1 as one of 256 levels, rounded to the nearest, halves up.
    static func level(_ value: Float) -> UInt8 {
        UInt8((unit(value) * 255 + 0.5).rounded(.down))
    }

    /// A colour multiplied by `alpha` as its own sRGB-encoded value; nothing under no alpha.
    static func encoded(_ component: Float, under alpha: Float) -> Float {
        alpha > 0 ? IEC_61966.SRGB.TransferFunction.encoded(unit(component / alpha)) : 0
    }
}
