public import Motion

extension Motion.Encoding {
    public enum Error: Swift.Error, Sendable, Hashable {
        /// AVFoundation cannot tag this signal.
        case signal(ITU_T_H_273.Signal)
        /// The raster for frame `index` was missing or of another size.
        case frame(Int)
        /// The rate's numerator or denominator, in lowest terms, does not fit an MP4 timescale.
        case rate(Rate)
        case writer(String)
    }
}
