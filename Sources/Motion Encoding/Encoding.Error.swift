public import Motion

extension Encoding {
    public enum Error: Swift.Error, Sendable, Hashable {
        /// AVFoundation cannot tag this signal.
        case signal(ITU_T_H_273.Signal)
        /// The raster for frame `index` was missing or of another size.
        case frame(Int)
        case writer(String)
    }
}
