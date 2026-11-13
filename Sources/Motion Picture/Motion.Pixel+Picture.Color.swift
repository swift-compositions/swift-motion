#if Picture
    public import Motion
    public import Picture

    extension Picture.Color {
        /// The colour a frame's pixel writes: each of red, green and blue divided by alpha as its sRGB-encoded
        /// value over 255, and alpha over 255. A pixel with no alpha is `clear`.
        public init(_ pixel: Motion.Pixel) {
            guard pixel.alpha > 0 else {
                self = .clear
                return
            }
            let alpha = Float(pixel.alpha)
            self.init(red: Float(pixel.red) / alpha, green: Float(pixel.green) / alpha, blue: Float(pixel.blue) / alpha, alpha: alpha / 255)
        }
    }
#endif
