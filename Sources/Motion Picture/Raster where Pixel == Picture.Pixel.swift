#if Picture
    public import Motion
    public import Picture

    extension Raster where Pixel == Picture::Picture.Pixel {
        /// A frame's raster as working pixels, each pixel as `Picture.Pixel.init(_:)` of a `Motion.Pixel` makes
        /// it: sRGB 8-bit premultiplied into linear light, premultiplied. It is the inverse of turning working
        /// pixels into a frame's: `map { Motion.Pixel($0) }` of the result is the raster it was made from, pixel
        /// for pixel.
        public init(_ raster: Raster<Motion.Pixel>) {
            self = raster.map { pixel in Picture::Picture.Pixel(pixel) }
        }
    }
#endif
