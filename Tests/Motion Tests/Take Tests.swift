import FIPS_180_4
import Motion
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
}
