public import Raster

extension Motion.Render {
    /// How two renders of the same frames compare, frame by frame.
    public struct Comparison: Hashable, Sendable {
        /// The pairs compared: the frames both renders have.
        public var frames: Cardinal
        /// The pairs that are the same picture.
        public var identical: Cardinal
        /// Among the pairs that differ, the one with the lowest PSNR; the first such on a tie.
        public var lowest: Lowest?
        /// The pairs of different sizes, which no PSNR compares.
        public var resized: [Ordinal]
        /// The frames one render has beyond the end of the other.
        public var unmatched: Cardinal

        /// Compares the renders position by position, in one pass over each.
        public init(_ first: some Swift.Sequence<Raster<Motion.Pixel>>, _ second: some Swift.Sequence<Raster<Motion.Pixel>>) {
            self.init(frames: .zero, identical: .zero, lowest: nil, resized: [], unmatched: .zero)
            var (mine, theirs) = (first.makeIterator(), second.makeIterator())
            var frame = Ordinal.zero
            while true {
                switch (mine.next(), theirs.next()) {
                case (let one?, let other?):
                    frames += Cardinal.one
                    if one == other {
                        identical += Cardinal.one
                    } else if let psnr = one.psnr(against: other) {
                        if psnr < lowest?.psnr ?? .infinity { lowest = Lowest(frame: frame, psnr: psnr) }
                    } else {
                        resized.append(frame)
                    }
                    frame += Cardinal.one

                case (.some, nil), (nil, .some):
                    unmatched += Cardinal.one

                case (nil, nil):
                    return
                }
            }
        }

        init(frames: Cardinal, identical: Cardinal, lowest: Lowest?, resized: [Ordinal], unmatched: Cardinal) {
            self.frames = frames
            self.identical = identical
            self.lowest = lowest
            self.resized = resized
            self.unmatched = unmatched
        }
    }
}
