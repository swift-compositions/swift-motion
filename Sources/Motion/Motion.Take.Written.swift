import Binary
public import Byte
import FIPS_180_4
import Integer
import RFC_1951
import Rate

extension Motion.Take {
    /// A take's written form, version 1, every number an unsigned integer little-endian.
    ///
    /// The head is 44 bytes: the eight bytes of `signature`, the version in four, then the rate's numerator and
    /// denominator, the width and the height in eight each. Then each distinct frame's pixels, in blue, green,
    /// red, alpha order, row after row, premultiplied as a `Motion.Pixel` is, compressed by DEFLATE (RFC 1951)
    /// at its fast level, in the order the frames first appear. Then the index: the number of frames in eight
    /// bytes and, for each frame in order, where its compressed pixels begin and how many bytes they are, eight
    /// bytes each, and its digest in 32; a frame equal to one before it names the same bytes. Then the foot,
    /// 48 bytes: where the index begins, the SHA-256 of the head and the index together, and the signature
    /// again.
    public enum Written {}
}

extension Motion.Take.Written {
    /// The first and the last eight bytes of a take's written form.
    public static let signature: [Byte] = [0x8A, 0x4D, 0x54, 0x4B, 0x0D, 0x0A, 0x1A, 0x0A].map(Byte.init(bitPattern:))

    /// The version this package writes, and the one it reads.
    public static let version: UInt32 = 1

    /// The bytes of the head, of one frame's entry in the index, and of the foot.
    static let head = 44
    static let entry = 48
    static let foot = 48
}

extension Motion.Take.Written {
    /// The take whose written form a function reads, as `Motion.Take.init(length:reading:)` says.
    static func take(
        length: UInt64,
        reading read: @escaping @Sendable (UInt64, Int) throws(Motion.Take.Error) -> [Byte]
    ) throws(Motion.Take.Error) -> Motion.Take {
        let head = try read(0, Int(Swift.min(length, UInt64(Self.head))))
        guard head.count >= 8, Array(head[0..<8]) == signature else { throw .foreign }
        guard head.count >= 12 else { throw .truncated }
        let version = UInt32(bytes: head[8..<12], endianness: .little) ?? 0
        guard version == Self.version else { throw .version(version) }
        guard head.count == Self.head, length >= UInt64(Self.head + 8 + Self.foot) else { throw .truncated }
        let end = length - UInt64(Self.foot)
        let foot = try exactly(read, end, Self.foot)
        guard Array(foot[40..<48]) == signature else { throw .truncated }
        let start = number(foot, at: 0)
        guard start >= UInt64(Self.head), start <= end - 8, end - start <= UInt64(Int.max) else { throw .index }
        let index = try exactly(read, start, Int(end - start))
        var hasher = FIPS_180_4.SHA256.Hasher()
        hasher.update(head)
        hasher.update(index)
        guard hasher.finalize().bytes == Array(foot[8..<40]) else { throw .index }
        let count = number(index, at: 0)
        guard UInt64(index.count - 8) % UInt64(entry) == 0, count == UInt64(index.count - 8) / UInt64(entry) else { throw .index }
        let rate: Rate
        do throws(Rate.Error) {
            rate = try Rate(Integer(number(head, at: 12)), per: Integer(number(head, at: 20)))
        } catch {
            throw .index
        }
        guard let width = UInt(exactly: number(head, at: 28)), let height = UInt(exactly: number(head, at: 36)) else { throw .index }
        let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow, pixels <= UInt(Int.max / 4) else { throw .index }
        let entries = try (0..<Int(count)).map { (place: Int) throws(Motion.Take.Error) -> Entry in
            let at = 8 + place * entry
            let entry = Entry(
                offset: number(index, at: at),
                length: number(index, at: at + 8),
                digest: FIPS_180_4.Digest(bytes: Array(index[(at + 16)..<(at + 48)]))
            )
            guard entry.offset >= UInt64(Self.head), entry.length <= start, entry.offset <= start - entry.length else { throw .index }
            return entry
        }
        return take(entries, rate: rate, width: Cardinal(width), height: Cardinal(height), reading: read)
    }

    /// The take of some entries, each frame reading its own bytes through a function when asked.
    static func take(
        _ entries: [Entry],
        rate: Rate,
        width: Cardinal,
        height: Cardinal,
        reading read: @escaping @Sendable (UInt64, Int) throws(Motion.Take.Error) -> [Byte]
    ) -> Motion.Take {
        let frames = entries.enumerated().map { place, entry in
            let position = Ordinal(UInt(place))
            return Motion.Take.Frame(width: width, height: height, digest: entry.digest) { () throws(Motion.Take.Error) -> Raster<Motion.Pixel> in
                guard entry.length <= UInt64(Int.max) else { throw .index }
                let compressed = try exactly(read, entry.offset, Int(entry.length))
                return try raster(compressed, width: width, height: height, digest: entry.digest, at: position)
            }
        }
        return Motion.Take(frames: frames, rate: rate, width: width, height: height)
    }

    /// A frame's raster from its compressed pixels, checked against its digest.
    static func raster(
        _ compressed: [Byte],
        width: Cardinal,
        height: Cardinal,
        digest: FIPS_180_4.Digest,
        at position: Ordinal
    ) throws(Motion.Take.Error) -> Raster<Motion.Pixel> {
        let inflated: [Byte]
        do throws(RFC_1951.Error) {
            inflated = try RFC_1951.decompress(compressed)
        } catch {
            throw .damaged(position)
        }
        let raster: Raster<Motion.Pixel>
        do throws(Motion.Pixel.Error) {
            raster = try unsafe Raster(width: width, height: height, bytes: inflated.span.bytes)
        } catch {
            throw .damaged(position)
        }
        guard Motion.Take.Frame.digest(of: raster) == digest else { throw .damaged(position) }
        return raster
    }

    /// A raster's pixels compressed as the written form keeps them.
    static func compressed(_ raster: Raster<Motion.Pixel>) -> [Byte] {
        let bytes = raster.pixels.withUnsafeBytes { source in
            unsafe [Byte](unsafeUninitializedCapacity: source.count) { target, count in
                unsafe UnsafeMutableRawBufferPointer(target).copyMemory(from: source)
                count = source.count
            }
        }
        return RFC_1951.compress(bytes, level: .fast)
    }

    /// Exactly `count` bytes from an offset, or `.truncated` where the bytes end first.
    static func exactly(
        _ read: (UInt64, Int) throws(Motion.Take.Error) -> [Byte],
        _ offset: UInt64,
        _ count: Int
    ) throws(Motion.Take.Error) -> [Byte] {
        let bytes = try read(offset, count)
        guard bytes.count == count else { throw .truncated }
        return bytes
    }

    /// The eight bytes at an offset as an unsigned integer, little-endian; the caller has checked they are there.
    static func number(_ bytes: [Byte], at offset: Int) -> UInt64 {
        UInt64(bytes: bytes[offset..<(offset + 8)], endianness: .little) ?? 0
    }
}
