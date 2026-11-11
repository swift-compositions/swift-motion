public import Motion

extension Motion.Encoding {
    public enum Error: Swift.Error, Sendable, Hashable {
        /// AVFoundation cannot tag this signal.
        case signal(ITU_T_H_273.Signal)
        /// The raster for the frame at this position was missing or of another size.
        case frame(Ordinal)
        /// The rate's numerator or denominator, in lowest terms, does not fit an MP4 timescale.
        case rate(Rate)
        /// The width, height or bit rate is more than AVFoundation can be told.
        case size(width: Cardinal, height: Cardinal, bits: Cardinal)
        /// This many frames end later than the movie's timescale can say.
        case length(Cardinal)
        case writer(String)
        /// The movie could not be read back.
        case reader(String)
    }
}
