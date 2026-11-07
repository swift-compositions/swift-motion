public import Motion

/// How frames become an H.264 MP4: size, exact rate, colour signal and bit rate.
///
/// The movie's timescale is the rate's own numerator, so each frame lasts exactly
/// `denominator` ticks (1001 at 30000/1001), and the `colr` box carries the H.273 signal.
public struct Encoding: Sendable, Hashable {
    public var width: Int
    public var height: Int
    public var rate: Frame.Rate
    public var signal: ITU_T_H_273.Signal
    public var bitRate: Int

    /// Frames rendered in sRGB, carried through the BT.709 matrix, are tagged 1-13-1 at limited range.
    public init(
        width: Int,
        height: Int,
        rate: Frame.Rate,
        signal: ITU_T_H_273.Signal = ITU_T_H_273.Signal.sRGB.carried(by: .bt709),
        bitRate: Int? = nil
    ) {
        self.width = width
        self.height = height
        self.rate = rate
        self.signal = signal
        self.bitRate = bitRate ?? width * height * 4
    }
}
