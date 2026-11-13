#if Picture
    import Motion
    import Picture
    import W3C_PNG

    extension Motion.Reel {
        /// What is kept of a frame drawn for a proof: a small copy for each number of columns of the sheets it is
        /// on, and its PNG where it is a still.
        struct Tile: Sendable {
            let small: [Cardinal: Raster<Picture::Picture.Pixel>]
            let still: Result<[Byte], W3C_PNG.Image.Error>?
        }
    }
#endif
