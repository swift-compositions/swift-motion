extension Raster {
    public enum Error: Swift.Error, Hashable, Sendable {
        case stride(Int, needed: Int)
        case size(Int, needed: Int)
        /// A colour channel exceeds the pixel's alpha, which premultiplied pixels never do.
        case premultiplied(x: Int, y: Int)
    }
}
