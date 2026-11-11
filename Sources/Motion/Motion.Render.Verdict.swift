public import Raster

extension Motion.Render {
    public enum Verdict: Hashable, Sendable {
        case deterministic
        case varies(frame: Ordinal, psnr: Double)
        /// The frame rendered twice at different sizes, so no PSNR compares the two.
        case resized(frame: Ordinal)
    }
}
