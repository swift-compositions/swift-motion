public import Rate
public import Rational

extension Motion {
    /// A recording: a run of frames at a rate, already drawn, whatever drew them, all of one size.
    ///
    /// A take holds pixels and says nothing of where they came from: a live view captured frame by frame, a
    /// movie read back, or rasters made by hand. Each frame carries the digest of its content, made once when
    /// the take is made, so a frame is told apart from another by that digest and never by its pixels again.
    public struct Take: Sendable, Hashable {
        /// The rate the frames were recorded at.
        public let rate: Rate

        /// The frames' width and height in pixels; zero for a take of no frames.
        public let width: Cardinal
        public let height: Cardinal

        /// The frames, in the order they were recorded.
        public let frames: [Frame]

        /// A take of frames at a rate. It fails with `.size` and the position of the first frame whose size is
        /// not the first frame's.
        public init(_ frames: [Frame], rate: Rate) throws(Error) {
            (self.width, self.height) = try Self.size(of: frames)
            self.rate = rate
            self.frames = frames
        }

        /// A take of rasters at a rate, each made a `Frame` and so digested once; it fails as
        /// `init(_:rate:)` of the frames does.
        public init(_ rasters: [Raster<Motion.Pixel>], rate: Rate) throws(Error) {
            let frames = rasters.map(Frame.init)
            (self.width, self.height) = try Self.size(of: frames)
            self.rate = rate
            self.frames = frames
        }
    }
}

extension Motion.Take {
    /// The frame shown at an instant in seconds from the take's start: the one at `rate.index(at:)` of it, so at
    /// a frame's start and center alike that frame, at any rate; nil before zero and from the end of the last
    /// frame on.
    public func position(at instant: Rational) -> Ordinal? {
        guard instant >= .zero, let index = rate.index(at: instant).exactly(UInt.self), index < UInt(frames.count) else { return nil }
        return Ordinal(index)
    }

    /// The frame `position(at:)` gives, or nil.
    public func frame(at instant: Rational) -> Frame? {
        position(at: instant).map { frames[Int(bitPattern: $0)] }
    }
}

extension Motion.Take {
    /// The first frame's width and height, zero without frames, or `.size` of the first frame of another size.
    static func size(of frames: [Frame]) throws(Error) -> (Cardinal, Cardinal) {
        let width = frames.first?.raster.width ?? .zero
        let height = frames.first?.raster.height ?? .zero
        if let wrong = frames.firstIndex(where: { $0.raster.width != width || $0.raster.height != height }) {
            throw .size(Ordinal(UInt(wrong)))
        }
        return (width, height)
    }
}
