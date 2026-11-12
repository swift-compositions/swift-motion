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
    /// Alpha is held to 0…1 and becomes one of 256 levels, rounded to the nearest, halves up. Each
    /// colour is divided by alpha, held to 0…1, put through the sRGB transfer function and becomes
    /// one of 256 levels the same way, as if it were opaque. That level is then multiplied by alpha's
    /// level over 255, rounded to the nearest, halves up, since a frame's colours are multiplied in
    /// their encoded form. So an opaque colour is exactly its sRGB level, a full colour under any
    /// alpha is exactly that alpha's level, light brighter than white is white, anything that is not
    /// a number is nothing, and no colour comes out above its alpha: the result is always a pixel.
    public init(linear red: Float, green: Float, blue: Float, alpha: Float) {
        let alpha = Self.unit(alpha)
        let cover = Self.level(alpha)
        self.blue = Self.scaled(Self.level(Self.encoded(blue, under: alpha)), by: cover)
        self.green = Self.scaled(Self.level(Self.encoded(green, under: alpha)), by: cover)
        self.red = Self.scaled(Self.level(Self.encoded(red, under: alpha)), by: cover)
        self.alpha = cover
    }

    /// A level multiplied by another level over 255, rounded to the nearest, halves up.
    static func scaled(_ level: UInt8, by cover: UInt8) -> UInt8 {
        UInt8((UInt(level) * UInt(cover) * 2 + 255) / 510)
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
