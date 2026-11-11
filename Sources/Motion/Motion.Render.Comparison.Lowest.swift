public import Raster

extension Motion.Render.Comparison {
    /// The frame where two renders are furthest apart, and the PSNR between its two pictures.
    public struct Lowest: Hashable, Sendable {
        public var frame: Ordinal
        public var psnr: Double

        public init(frame: Ordinal, psnr: Double) {
            self.frame = frame
            self.psnr = psnr
        }
    }
}
