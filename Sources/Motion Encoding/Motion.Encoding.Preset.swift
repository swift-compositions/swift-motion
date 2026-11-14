public import Motion

extension Motion.Encoding {
    /// A size a movie is made smaller to for sharing: the largest picture of the preset's shape it fits within.
    public enum Preset: Swift.String, Sendable, Hashable, CaseIterable {
        /// Within 960 × 540.
        case height540 = "540"

        /// Within 1280 × 720.
        case height720 = "720"

        /// Within 1920 × 1080.
        case height1080 = "1080"
    }
}

extension Motion.Encoding.Preset {
    /// The width and height a picture is fitted within.
    var box: (width: Int, height: Int) {
        switch self {
        case .height540: (960, 540)

        case .height720: (1280, 720)

        case .height1080: (1920, 1080)
        }
    }

    /// The largest size of a picture's shape within the box and no larger than the picture, each side
    /// rounded down to an even number of pixels and at least `Motion.Encoding.side`.
    func fit(width: Cardinal, height: Cardinal) -> (width: Cardinal, height: Cardinal) {
        let (wide, tall) = (Int(clamping: width), Int(clamping: height))
        let (across, down) = box
        var fitted = (wide, tall)
        if wide > across || tall > down {
            fitted = wide * down >= tall * across ? (across, tall * across / Swift.max(wide, 1)) : (wide * down / Swift.max(tall, 1), down)
        }
        let floor: Int = Int(clamping: Motion.Encoding.side)
        let wider: UInt = UInt(Swift.max(Motion.Encoding.even(fitted.0), floor))
        let taller: UInt = UInt(Swift.max(Motion.Encoding.even(fitted.1), floor))
        return (Cardinal(wider), Cardinal(taller))
    }
}
