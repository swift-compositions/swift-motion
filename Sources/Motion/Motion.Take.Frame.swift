public import FIPS_180_4

extension Motion.Take {
    /// A frame of a take: its raster and the SHA-256 digest of its content, made once when the frame is made.
    ///
    /// The digest is of the width and the height, each as eight bytes little-endian, and then the pixels' bytes
    /// in blue, green, red, alpha order, row after row: a function of the raster alone, the same in every
    /// process and every run. Two frames are equal and hash alike exactly when their digests are, so comparing
    /// and hashing a frame reads 32 bytes, never its pixels.
    public struct Frame: Sendable {
        public let raster: Raster<Motion.Pixel>
        public let digest: FIPS_180_4.Digest

        public init(_ raster: Raster<Motion.Pixel>) {
            var hasher = FIPS_180_4.SHA256.Hasher()
            var head: [UInt8] = []
            for size in [raster.width, raster.height] {
                withUnsafeBytes(of: UInt64(Int(clamping: size)).littleEndian) { unsafe head.append(contentsOf: $0) }
            }
            hasher.update(head.span.bytes)
            raster.pixels.withUnsafeBytes { bytes in
                unsafe hasher.update(RawSpan(_unsafeBytes: bytes))
            }
            self.raster = raster
            self.digest = hasher.finalize()
        }
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
