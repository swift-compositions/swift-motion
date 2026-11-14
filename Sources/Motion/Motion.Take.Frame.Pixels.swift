extension Motion.Take.Frame {
    /// Where a frame's pixels are: held in memory, or read by a function each time they are asked for.
    enum Pixels: Sendable {
        case held(Raster<Motion.Pixel>)
        case read(@Sendable () throws(Motion.Take.Error) -> Raster<Motion.Pixel>)
    }
}
