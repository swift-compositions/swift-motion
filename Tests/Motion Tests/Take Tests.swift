import Byte
import FIPS_180_4
import Motion
import Synchronization
import Testing

@Suite struct `Take Tests` {
    static func raster(width: Int, height: Int, seed: Int) throws -> Raster<Motion.Pixel> {
        let bytes = (0..<(width * height)).flatMap { index -> [UInt8] in
            let alpha = UInt8(truncatingIfNeeded: 128 + (index * 7 + seed) % 128)
            return [UInt8((index + seed) % (Int(alpha) + 1)), alpha / 2, alpha / 3, alpha]
        }
        return try Raster(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), bytes: bytes)
    }

    @Test func `a frame's digest is the SHA-256 of its width, its height and its pixels' bytes`() throws {
        let raster = try Self.raster(width: 5, height: 3, seed: 1)
        var message: [UInt8] = []
        for size in [UInt64(5), UInt64(3)] { withUnsafeBytes(of: size.littleEndian) { unsafe message += $0 } }
        message += raster.bytes
        var hasher = FIPS_180_4.SHA256.Hasher()
        hasher.update(message.span.bytes)
        #expect(Motion.Take.Frame(raster).digest == hasher.finalize())
    }

    @Test func `frames of equal pixels are equal, and one differing pixel or another shape tells them apart`() throws {
        let first = Motion.Take.Frame(try Self.raster(width: 4, height: 2, seed: 3))
        let second = Motion.Take.Frame(try Self.raster(width: 4, height: 2, seed: 3))
        #expect(first == second && first.hashValue == second.hashValue)
        var bytes = try Self.raster(width: 4, height: 2, seed: 3).bytes
        bytes[4 * 5] = bytes[4 * 5] == 0 ? 1 : 0
        let changed = Motion.Take.Frame(try Raster(width: 4, height: 2, bytes: bytes))
        #expect(changed != first)
        let turned = Motion.Take.Frame(try Raster(width: 2, height: 4, bytes: try Self.raster(width: 4, height: 2, seed: 3).bytes))
        #expect(turned != first)
    }

    @Test func `a take refuses a frame of another size by its position`() throws {
        let frames = [try Self.raster(width: 4, height: 2, seed: 0), try Self.raster(width: 4, height: 2, seed: 1), try Self.raster(width: 2, height: 4, seed: 2)]
        #expect(throws: Motion.Take.Error.size(2)) { try Motion.Take(frames, rate: .thirty) }
        let take = try Motion.Take(Array(frames.prefix(2)), rate: .thirty)
        #expect(take.width == 4 && take.height == 2 && take.frames.count == 2)
        let empty = try Motion.Take([Raster<Motion.Pixel>](), rate: .thirty)
        #expect(empty.width == .zero && empty.position(at: .zero) == nil)
    }

    @Test func `an instant shows the frame at the take's rate index of it, and none before zero or from the end on`() throws {
        let take = try Motion.Take((0..<4).map { try Self.raster(width: 2, height: 2, seed: $0) }, rate: .ntsc)
        let rate = Rate.ntsc
        (0..<4).forEach { k in
            #expect(take.position(at: rate.start(of: Integer(k))) == Ordinal(UInt(k)))
            #expect(take.position(at: rate.centre(of: Integer(k))) == Ordinal(UInt(k)))
            #expect(take.frame(at: rate.centre(of: Integer(k))) == take.frames[k])
        }
        #expect(take.position(at: rate.start(of: 4)) == nil)
        #expect(take.position(at: Rational.zero - rate.period * .half) == nil)
        let thirty = Rate.thirty
        let shown = (0..<8).map { take.position(at: thirty.centre(of: Integer($0))) }
        let expected = (0..<8).map { k -> Ordinal? in
            let index = rate.index(at: thirty.centre(of: Integer(k)))
            guard let place = index.exactly(UInt.self), place < 4 else { return nil }
            return Ordinal(place)
        }
        #expect(shown == expected)
    }

    @Test func `outside its frames a take shows nothing by default, and its nearest frame held when it extends`() throws {
        let take = try Motion.Take((0..<4).map { try Self.raster(width: 2, height: 2, seed: $0) }, rate: .ntsc)
        let rate = Rate.ntsc
        let before = Rational.zero - rate.period * .half
        #expect(take.position(at: before) == nil && take.position(at: before, outside: .empty) == nil)
        #expect(take.position(at: before, outside: .extend) == .zero)
        #expect(take.position(at: -1000, outside: .extend) == .zero)
        #expect(take.position(at: rate.start(of: 4), outside: .extend) == 3)
        #expect(take.position(at: 1000, outside: .extend) == 3)
        #expect(take.frame(at: rate.start(of: 4), outside: .extend) == take.frames[3])
        #expect(take.frame(at: before, outside: .extend) == take.frames[0])
        (0..<4).forEach { k in
            #expect(take.position(at: rate.centre(of: Integer(k)), outside: .extend) == Ordinal(UInt(k)))
        }
        let empty = try Motion.Take([Raster<Motion.Pixel>](), rate: .ntsc)
        for edge in Motion.Take.Edge.allCases {
            for instant in [before, .zero, 1] {
                #expect(empty.position(at: instant, outside: edge) == nil && empty.frame(at: instant, outside: edge) == nil)
            }
        }
    }

    static let seeds = [0, 1, 0, 2, 2, 0]

    /// A take of non-opaque frames at 29.97 whose first frame comes back twice and whose third comes back once more.
    static func repeated() throws -> Motion.Take {
        try Motion.Take(seeds.map { try raster(width: 6, height: 4, seed: $0) }, rate: .ntsc)
    }

    /// The bytes each frame added to the written form, in order, after the head: empty for a frame written before.
    static func pieces(of take: Motion.Take) throws -> (head: Int, frames: [[Byte]], tail: [Byte]) {
        var writer = try Motion.Take.Writer(rate: take.rate)
        var frames: [[Byte]] = []
        for frame in take.frames { frames.append(try writer.append(frame)) }
        let head = Motion.Take.Written.signature.count + 36
        frames[0].removeFirst(head)
        return (head, frames, writer.tail())
    }

    /// The ranges a reading function was asked for.
    final class Asked: Sendable {
        let ranges = Mutex<[Range<UInt64>]>([])
        func withLock<Value>(_ body: (inout [Range<UInt64>]) -> Value) -> Value { ranges.withLock { body(&$0) } }
    }

    /// A function reading from bytes that notes every range it is asked for.
    static func reading(_ bytes: [Byte], into asked: Asked) -> @Sendable (UInt64, Int) throws(Motion.Take.Error) -> [Byte] {
        { (offset: UInt64, count: Int) throws(Motion.Take.Error) -> [Byte] in
            asked.withLock { $0.append(offset..<(offset + UInt64(count))) }
            let start = Int(Swift.min(offset, UInt64(bytes.count)))
            return Array(bytes[start..<Swift.min(start + count, bytes.count)])
        }
    }

    @Test func `a take written and read back is equal, frame for frame, raster for raster, digest for digest`() throws {
        let take = try Self.repeated()
        let read = try Motion.Take(written: take.written())
        #expect(read == take)
        #expect(read.rate == .ntsc && read.width == take.width && read.height == take.height)
        #expect(read.frames.map(\.digest) == take.frames.map(\.digest))
        #expect(try read.frames.map { try $0.raster() } == take.frames.map { try $0.raster() })
        #expect(read.frames.allSatisfy { $0.held == nil })
        let empty = try Motion.Take([Raster<Motion.Pixel>](), rate: .film)
        let none = try Motion.Take(written: empty.written())
        #expect(none == empty && none.rate == .film && none.width == .zero && none.frames.isEmpty)
    }

    @Test func `a frame repeated in a take is written once and named again in the index`() throws {
        let take = try Self.repeated()
        let distinct = try Motion.Take([0, 1, 2].map { try Self.raster(width: 6, height: 4, seed: $0) }, rate: .ntsc)
        let pieces = try Self.pieces(of: take)
        #expect(pieces.frames.map(\.isEmpty) == [false, false, true, false, true, true])
        #expect(try take.written().count == distinct.written().count + 3 * 48)
    }

    @Test func `the writer's own take is the take read back from its bytes`() throws {
        let take = try Self.repeated()
        let bytes = try take.written()
        var writer = try Motion.Take.Writer(rate: take.rate)
        for frame in take.frames { _ = try writer.append(frame) }
        let asked = Asked()
        let kept = writer.take(reading: Self.reading(bytes, into: asked))
        #expect(kept == take && kept.width == take.width)
        #expect(try kept.frames.map { try $0.raster() } == take.frames.map { try $0.raster() })
    }

    @Test func `reading a take reads its head, index and foot and no frame; reading frame i reads frame i's bytes alone`() throws {
        let take = try Self.repeated()
        let bytes = try take.written()
        let pieces = try Self.pieces(of: take)
        var starts: [UInt64] = []
        var end = UInt64(pieces.head)
        for piece in pieces.frames where !piece.isEmpty {
            starts.append(end)
            end += UInt64(piece.count)
        }
        let frames = UInt64(pieces.head)..<end
        let asked = Asked()
        let read = try Motion.Take(length: UInt64(bytes.count), reading: Self.reading(bytes, into: asked))
        #expect(asked.withLock { $0 }.allSatisfy { !$0.overlaps(frames) })
        for (position, frame) in read.frames.enumerated() {
            asked.withLock { $0 = [] }
            _ = try frame.raster()
            let distinct = Self.seeds[position]
            let own = starts[distinct]..<(distinct + 1 < starts.count ? starts[distinct + 1] : end)
            #expect(asked.withLock { $0 } == [own])
        }
    }

    @Test func `a damaged frame fails with its position and leaves the other frames readable`() throws {
        let take = try Self.repeated()
        var bytes = try take.written()
        let pieces = try Self.pieces(of: take)
        let middle = pieces.head + pieces.frames[0].count + pieces.frames[1].count / 2
        bytes[middle] = Byte(bitPattern: ~bytes[middle].bitPattern)
        let read = try Motion.Take(written: bytes)
        #expect(throws: Motion.Take.Error.damaged(1)) { try read.frames[1].raster() }
        #expect(try read.frames[0].raster() == take.frames[0].raster())
        #expect(try read.frames[3].raster() == take.frames[3].raster())
    }

    @Test func `bytes cut short anywhere after the signature fail as truncated, and before it as foreign`() throws {
        let bytes = try Self.repeated().written()
        (0..<8).forEach { length in
            #expect(throws: Motion.Take.Error.foreign) { try Motion.Take(written: Array(bytes.prefix(length))) }
        }
        (8..<bytes.count).forEach { length in
            #expect(throws: Motion.Take.Error.truncated) { try Motion.Take(written: Array(bytes.prefix(length))) }
        }
    }

    @Test func `a frame whose bytes end early when it is read fails as truncated`() throws {
        let bytes = try Self.repeated().written()
        let first = UInt64(try Self.pieces(of: Self.repeated()).head)
        let cut = try Motion.Take(length: UInt64(bytes.count)) { (offset: UInt64, count: Int) throws(Motion.Take.Error) -> [Byte] in
            let start = Int(offset)
            let read = Array(bytes[start..<Swift.min(start + count, bytes.count)])
            return offset == first ? Array(read.dropLast()) : read
        }
        #expect(throws: Motion.Take.Error.truncated) { try cut.frames[0].raster() }
        #expect(try cut.frames[1].raster() == Self.repeated().frames[1].raster())
    }

    @Test func `another version fails with that version, and foreign bytes as foreign`() throws {
        var bytes = try Self.repeated().written()
        bytes[8] = Byte(bitPattern: 2)
        #expect(throws: Motion.Take.Error.version(2)) { try Motion.Take(written: bytes) }
        let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13]
        #expect(throws: Motion.Take.Error.foreign) { try Motion.Take(written: png.map(Byte.init(bitPattern:))) }
        #expect(throws: Motion.Take.Error.foreign) { try Motion.Take(written: []) }
    }

    @Test func `a changed head or index fails its check`() throws {
        let take = try Self.repeated()
        let bytes = try take.written()
        let index = bytes.count - 48 - (8 + take.frames.count * 48)
        for place in [12, 20, 28, 36, index, index + 8 + 3, index + 8 + 16, bytes.count - 48] {
            var changed = bytes
            changed[place] = Byte(bitPattern: changed[place].bitPattern ^ 1)
            #expect(throws: Motion.Take.Error.index) { try Motion.Take(written: changed) }
        }
    }

    @Test func `a rate the written form cannot hold is refused before anything is written`() throws {
        let huge = try Rate(Integer(UInt64.max) * Integer(4), per: 3)
        #expect(throws: Motion.Take.Error.rate) { try Motion.Take.Writer(rate: huge) }
        var writer = try Motion.Take.Writer(rate: .thirty)
        _ = try writer.append(Motion.Take.Frame(try Self.raster(width: 2, height: 2, seed: 0)))
        #expect(throws: Motion.Take.Error.size(1)) { try writer.append(Motion.Take.Frame(try Self.raster(width: 3, height: 2, seed: 0))) }
        #expect(writer.count == 1)
    }
}
