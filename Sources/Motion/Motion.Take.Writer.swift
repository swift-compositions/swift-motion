import Binary
public import Byte
public import FIPS_180_4

extension Motion.Take {
    /// Writes a take's written form a frame at a time, so a take is written as it is recorded, without holding
    /// its frames: each `append(_:)` gives the bytes to add after those given before, and `tail()` the bytes
    /// that end the form. The size is the first frame's; the head goes out with it.
    ///
    /// A frame whose digest was written before is written as an index entry naming the same bytes, and its pixels
    /// are not read. The writer holds, for each frame, where its bytes are and its digest: 48 bytes a frame and no
    /// pixels.
    public struct Writer: Sendable {
        /// The rate the take is written at.
        public let rate: Rate

        /// The frames' width and height, the first frame's; zero before it.
        public private(set) var width: Cardinal = .zero
        public private(set) var height: Cardinal = .zero

        let numerator: UInt64
        let denominator: UInt64
        var entries: [Written.Entry] = []
        var kept: [FIPS_180_4.Digest: Written.Entry] = [:]
        var end = UInt64(Written.head)

        /// A writer of a take at a rate; it fails with `.rate` when the rate's numerator or denominator does not
        /// fit 64 bits.
        public init(rate: Rate) throws(Motion.Take.Error) {
            guard let numerator = rate.frequency.numerator.exactly(UInt64.self),
                let denominator = rate.frequency.denominator.exactly(UInt64.self)
            else { throw .rate }
            self.rate = rate
            self.numerator = numerator
            self.denominator = denominator
        }
    }
}

extension Motion.Take.Writer {
    /// How many frames have been appended.
    public var count: Int { entries.count }

    /// The bytes that write a frame after those written before: with the first frame the head, then the frame's
    /// compressed pixels, or nothing for a frame whose digest was written before. A frame not of the first
    /// frame's size fails with `.size` and its position and is not written; a frame whose pixels cannot be read
    /// fails as reading them does.
    public mutating func append(_ frame: Motion.Take.Frame) throws(Motion.Take.Error) -> [Byte] {
        if entries.isEmpty {
            (width, height) = (frame.width, frame.height)
        } else if frame.width != width || frame.height != height {
            throw .size(Ordinal(UInt(entries.count)))
        }
        if let entry = kept[frame.digest] {
            entries.append(entry)
            return opening()
        }
        let compressed = Motion.Take.Written.compressed(try frame.raster())
        let entry = Motion.Take.Written.Entry(offset: end, length: UInt64(compressed.count), digest: frame.digest)
        kept[frame.digest] = entry
        entries.append(entry)
        end += UInt64(compressed.count)
        return opening() + compressed
    }

    /// The bytes that end the form, after every frame's: the head if no frame was appended, the index and the
    /// foot.
    public func tail() -> [Byte] {
        var index: [Byte] = []
        index.reserveCapacity(8 + entries.count * Motion.Take.Written.entry)
        UInt64(entries.count).bytes(into: &index, endianness: .little)
        for entry in entries {
            entry.offset.bytes(into: &index, endianness: .little)
            entry.length.bytes(into: &index, endianness: .little)
            index += entry.digest.bytes
        }
        var hasher = FIPS_180_4.SHA256.Hasher()
        hasher.update(head)
        hasher.update(index)
        var foot: [Byte] = []
        end.bytes(into: &foot, endianness: .little)
        foot += hasher.finalize().bytes
        foot += Motion.Take.Written.signature
        return (entries.isEmpty ? head : []) + index + foot
    }

    /// The take the written form holds, its frames reading their bytes through a function as
    /// `Motion.Take.init(length:reading:)` gives them, without reading the form back.
    public func take(reading read: @escaping @Sendable (_ offset: UInt64, _ count: Int) throws(Motion.Take.Error) -> [Byte]) -> Motion.Take {
        Motion.Take.Written.take(entries, rate: rate, width: width, height: height, reading: read)
    }
}

extension Motion.Take.Writer {
    /// The head: the signature, the version, the rate, the width and the height.
    var head: [Byte] {
        var head = Motion.Take.Written.signature
        Motion.Take.Written.version.bytes(into: &head, endianness: .little)
        for number in [numerator, denominator, UInt64(Int(clamping: width)), UInt64(Int(clamping: height))] {
            number.bytes(into: &head, endianness: .little)
        }
        return head
    }

    /// The head when the frame just appended is the first, and nothing otherwise.
    func opening() -> [Byte] {
        entries.count == 1 ? head : []
    }
}
