public import Byte
public import Rate
public import Rational

extension Motion {
    /// A recording: a run of frames at a rate, already drawn, whatever drew them, all of one size.
    ///
    /// A take holds pixels and says nothing of where they came from: a live view captured frame by frame, a
    /// movie read back, or rasters made by hand. Each frame carries the digest of its content, made once when
    /// the take is made, so a frame is told apart from another by that digest and never by its pixels again.
    /// A take read from its written form holds no pixels: each frame reads its own when asked.
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

        /// A take of frames known to be of one size.
        init(frames: [Frame], rate: Rate, width: Cardinal, height: Cardinal) {
            self.rate = rate
            self.width = width
            self.height = height
            self.frames = frames
        }
    }
}

extension Motion.Take {
    /// The frame shown at an instant in seconds from the take's start: the one at `rate.index(at:)` of it, so at
    /// a frame's start and center alike that frame, at any rate. Outside the frames, before zero and from the end
    /// of the last frame on, it is what `outside` says: nil for `.empty`, the default, and the first or the last
    /// frame for `.extend`. A take of no frames shows none anywhere.
    public func position(at instant: Rational, outside: Edge = .empty) -> Ordinal? {
        guard let end = frames.indices.last else { return nil }
        let last = UInt(end)
        guard instant >= .zero else { return outside == .extend ? .zero : nil }
        guard let index = rate.index(at: instant).exactly(UInt.self), index <= last else { return outside == .extend ? Ordinal(last) : nil }
        return Ordinal(index)
    }

    /// The frame `position(at:outside:)` gives, or nil.
    public func frame(at instant: Rational, outside: Edge = .empty) -> Frame? {
        position(at: instant, outside: outside).map { frames[Int(bitPattern: $0)] }
    }
}

extension Motion.Take {
    /// The take in its written form, as `Writer` writes it: the head, each distinct frame's pixels once, the
    /// index and the foot. Frames that read their pixels are read once each; it fails as `Writer` does.
    public func written() throws(Error) -> [Byte] {
        var writer = try Writer(rate: rate)
        var bytes: [Byte] = []
        for frame in frames {
            bytes += try writer.append(frame)
        }
        return bytes + writer.tail()
    }

    /// The take whose written form these bytes are, its frames read from the bytes when asked; it fails as
    /// `init(length:reading:)` does.
    public init(written bytes: [Byte]) throws(Error) {
        self = try Written.take(length: UInt64(bytes.count)) { (offset: UInt64, count: Int) throws(Error) -> [Byte] in
            let start = Int(clamping: Swift.min(offset, UInt64(bytes.count)))
            return Array(bytes[start..<Swift.min(start + count, bytes.count)])
        }
    }

    /// The take whose written form is `length` bytes long, read through a function that gives up to `count`
    /// bytes from an offset, fewer only where the bytes end.
    ///
    /// The head, the index and the foot are read now and checked; no frame's pixels are read. Each frame reads
    /// its own bytes through the function each time its `raster()` is asked for, and nothing else, and checks
    /// them. Bytes that do not begin with the signature fail with `.foreign`, another version with `.version`,
    /// bytes that end before their foot or before a part they name with `.truncated`, a head or an index that
    /// fails its digest or names bytes outside the frames' with `.index`, and a frame read whose pixels are not
    /// its digest's with `.damaged` and its position. The function's own failure is passed on as it is.
    public init(
        length: UInt64,
        reading read: @escaping @Sendable (_ offset: UInt64, _ count: Int) throws(Error) -> [Byte]
    ) throws(Error) {
        self = try Written.take(length: length, reading: read)
    }
}

extension Motion.Take {
    /// The first frame's width and height, zero without frames, or `.size` of the first frame of another size.
    static func size(of frames: [Frame]) throws(Error) -> (Cardinal, Cardinal) {
        let width = frames.first?.width ?? .zero
        let height = frames.first?.height ?? .zero
        if let wrong = frames.firstIndex(where: { $0.width != width || $0.height != height }) {
            throw .size(Ordinal(UInt(wrong)))
        }
        return (width, height)
    }
}
