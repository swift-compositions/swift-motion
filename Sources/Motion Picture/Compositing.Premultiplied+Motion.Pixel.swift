#if Picture
    public import Motion
    public import Picture

    extension Compositing.Premultiplied where Scalar == Float {
        /// A frame's pixel as a working pixel. An opaque pixel's components are sRGB levels as they stand, and each
        /// becomes `Motion.Pixel.linear(_:)` of its level, which is within a millionth of what
        /// `Picture.Color(_:)` of the pixel gives; any other pixel is that colour as a working pixel.
        public init(_ pixel: Motion.Pixel) {
            guard pixel.alpha == 255 else {
                self = Picture::Picture.Color(pixel).pixel
                return
            }
            self.init(
                color: .init(
                    red: Motion.Pixel.linear(pixel.red),
                    green: Motion.Pixel.linear(pixel.green),
                    blue: Motion.Pixel.linear(pixel.blue)
                ),
                alpha: 1
            )
        }
    }
#endif
