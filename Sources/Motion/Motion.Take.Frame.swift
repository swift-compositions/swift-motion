import Binary
public import Byte
public import FIPS_180_4

extension Motion.Take {
    /// A frame of a take: its width, its height and the SHA-256 digest of its content, and its pixels, held or
    /// read when asked for.
    ///
    /// The digest is of the width and the height, each as eight bytes little-endian, and then the pixels' bytes
    /// in blue, green, red, alpha order, row after row: a function of the raster alone, the same in every
    /// process and every run. Two frames are equal and hash alike exactly when their digests are, so comparing
    /// and hashing a frame reads 32 bytes, never its pixels.
    ///
    /// A frame made from a raster holds it. A frame of a take read from its written form holds where its pixels
    /// are written, and `raster()` reads them each time it is asked and keeps nothing: the caller holds the raster
    /// for as long as it needs it.
    public struct Frame: Sendable {
        public let width: Cardinal
        public let height: Cardinal
        public let digest: FIPS_180_4.Digest
        let pixels: Pixels

        /// A frame holding a raster, digested once.
        public init(_ raster: Raster<Motion.Pixel>) {
            self.init(raster, digest: Self.digest(of: raster))
        }

        init(_ raster: Raster<Motion.Pixel>, digest: FIPS_180_4.Digest) {
            self.width = raster.width
            self.height = raster.height
            self.digest = digest
            self.pixels = .held(raster)
        }

        /// A frame whose pixels a function reads when they are asked for; it must give a raster of this size
        /// and digest, or fail.
        init(
            width: Cardinal,
            height: Cardinal,
            digest: FIPS_180_4.Digest,
            reading: @escaping @Sendable () throws(Motion.Take.Error) -> Raster<Motion.Pixel>
        ) {
            self.width = width
            self.height = height
            self.digest = digest
            self.pixels = .read(reading)
        }
    }
}

extension Motion.Take.Frame {
    /// The frame's pixels: the raster it holds, or the raster read now, which fails as reading it does.
    ///
    /// Reading may block the calling thread on the file it reads; call it from a thread that may wait, never
    /// from a task on the cooperative pool.
    public func raster() throws(Motion.Take.Error) -> Raster<Motion.Pixel> {
        switch pixels {
        case .held(let raster): raster
        case .read(let reading): try reading()
        }
    }

    /// The raster the frame holds, or nil for one that reads its pixels when asked.
    public var held: Raster<Motion.Pixel>? {
        if case .held(let raster) = pixels { raster } else { nil }
    }

    /// The SHA-256 of a raster's width and height, eight bytes each, little-endian, then its pixels' bytes.
    static func digest(of raster: Raster<Motion.Pixel>) -> FIPS_180_4.Digest {
        var hasher = FIPS_180_4.SHA256.Hasher()
        var head: [Byte] = []
        UInt64(Int(clamping: raster.width)).bytes(into: &head, endianness: .little)
        UInt64(Int(clamping: raster.height)).bytes(into: &head, endianness: .little)
        hasher.update(head)
        raster.pixels.withUnsafeBytes { bytes in
            unsafe hasher.update(RawSpan(_unsafeBytes: bytes))
        }
        return hasher.finalize()
    }
}

extension Motion.Take.Frame: Hashable {
    public static func == (first: Self, second: Self) -> Bool {
        first.digest == second.digest
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(digest)
    }
}
