public import Raster

extension Motion.Pixel {
    /// Why bytes could not be read as a raster of frame pixels.
    public enum Error: Swift.Error, Hashable, Sendable {
        /// Rows this many bytes apart cannot hold the `needed` bytes of one row's pixels.
        case stride(Cardinal, needed: Cardinal)
        /// This many bytes were given where `needed` make up the rows.
        case size(Cardinal, needed: Cardinal)
        /// A colour channel exceeds the pixel's alpha, which premultiplied pixels never do.
        case premultiplied(x: Ordinal, y: Ordinal)
        /// The width, height or stride asks for more bytes than an array can hold.
        case overflow
    }
}
