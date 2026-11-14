#if Picture
    import Motion
    import Motion_Picture
    import Picture
    import Picture_Store
    import File_System
    import Foundation
    import Standard_Library_Extensions
    import Testing

    @Suite struct `Take Tests` {
        static let width = 12
        static let height = 8

        static func raster(seed: Int, opaque: Bool = true, width: Int = width, height: Int = height) throws -> Raster<Motion.Pixel> {
            let bytes = (0..<(width * height)).flatMap { index -> [UInt8] in
                let alpha: UInt8 = opaque ? 255 : UInt8(truncatingIfNeeded: 64 + (index * 5 + seed) % 192)
                let level = UInt8(truncatingIfNeeded: index * 13 + seed * 31)
                return [UInt8(Int(level) % (Int(alpha) + 1)), UInt8(Int(255 - level) % (Int(alpha) + 1)), alpha / 2, alpha]
            }
            return try Raster(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), bytes: bytes)
        }

        static func take(_ seeds: [Int], rate: Rate = .thirty) throws -> Motion.Take {
            try Motion.Take(seeds.map { try raster(seed: $0) }, rate: rate)
        }

        @Test func `every frame pixel becomes a working pixel and comes back as itself`() {
            let pixels = (UInt8.min...UInt8.max).flatMap { alpha in
                (0...alpha).compactMap { level in Motion.Pixel(blue: level, green: alpha - level, red: level / 2, alpha: alpha) }
            }
            #expect(pixels.count == 256 * 257 / 2)
            #expect(pixels.allSatisfy { pixel in Motion.Pixel(Picture::Picture.Pixel(pixel)) == pixel })
        }

        @Test func `a frame's raster as working pixels comes back as itself`() throws {
            let raster = try Self.raster(seed: 4, opaque: false)
            #expect(Raster<Picture::Picture.Pixel>(raster).map { Motion.Pixel($0) } == raster)
        }

        @Test func `a reel part showing a take at the identity draws the take's frames, pixel for pixel`() async throws {
            let take = try Self.take([0, 1, 2], rate: .ntsc)
            let reel = Motion.Reel<Swift.String>(
                width: take.width,
                height: take.height,
                rate: .ntsc,
                parts: [.init("take", frames: 3) { frame in Picture(take, at: frame.time) }]
            )
            let drawn = try await reel.hosting(workers: 2).rasters([0, 1, 2])
            #expect(drawn == (try take.frames.map { try $0.raster() }))
        }

        @Test func `a frame placed at twice its size at the nearest pixel shows each pixel as a square of four`() async throws {
            let take = try Self.take([5])
            let width = Cardinal(UInt(Self.width * 2 + 3))
            let height = Cardinal(UInt(Self.height * 2 + 1))
            let placement = Picture.Transform(rows: [[2, 0, 3], [0, 2, 1]])
            let raster = try Motion.Hosting.Picture.raster(
                Picture(take, at: .zero, placement: placement, sampling: .nearest),
                width: width,
                height: height
            )
            let frame = try take.frames[0].raster()
            let squares = (0..<(Self.width * Self.height)).allSatisfy { index in
                let (x, y) = (index % Self.width, index / Self.width)
                let pixel = frame[x: Ordinal(UInt(x)), y: Ordinal(UInt(y))]
                return [(0, 0), (1, 0), (0, 1), (1, 1)].allSatisfy { dx, dy in
                    raster[x: Ordinal(UInt(3 + 2 * x + dx)), y: Ordinal(UInt(1 + 2 * y + dy))] == pixel
                }
            }
            #expect(squares)
            #expect(raster[x: 0, y: 0] == Motion.Pixel(blue: 0, green: 0, red: 0, alpha: 255))
        }

        @Test func `a take is empty before zero and from the end of its last frame on`() throws {
            let take = try Self.take([0, 1])
            #expect(Picture(take, at: Rational.zero - Rate.thirty.period * .half) == [])
            #expect(Picture(take, at: Rate.thirty.start(of: 2)) == [])
            #expect(Picture(take, at: Rate.thirty.start(of: 1)) == Picture(take.frames[1]))
        }

        @Test func `a take outside its frames holds its first and last frame when asked to extend, and an empty take shows nothing`() throws {
            let take = try Self.take([0, 1])
            #expect(Picture(take, at: Rational.zero - Rate.thirty.period * .half, outside: .extend) == Picture(take.frames[0]))
            #expect(Picture(take, at: Rate.thirty.start(of: 2), outside: .extend) == Picture(take.frames[1]))
            #expect(Picture(take, at: 100, outside: .extend) == Picture(take.frames[1]))
            #expect(Picture(take, at: Rate.thirty.start(of: 0), outside: .extend) == Picture(take.frames[0]))
            #expect(Picture(take, at: Rate.thirty.start(of: 2), outside: .empty) == [])
            let empty = try Motion.Take([Raster<Motion.Pixel>](), rate: .thirty)
            #expect(Picture(empty, at: .zero, outside: .extend) == [])
        }

        @Test func `equal takes give equal pictures and one stored entry; one differing pixel gives another`() async throws {
            let first = try Self.take([7])
            let second = try Self.take([7])
            var bytes = try Self.raster(seed: 7).bytes
            bytes[0] = bytes[0] == 0 ? 1 : 0
            let changed = try Motion.Take([try Raster(width: first.width, height: first.height, bytes: bytes)], rate: .thirty)
            #expect(Picture(first, at: .zero) == Picture(second, at: .zero))
            #expect(Picture(first, at: .zero).hashValue == Picture(second, at: .zero).hashValue)
            #expect(Picture(first, at: .zero) != Picture(changed, at: .zero))

            let path = "/tmp/motion-take-store-" + Swift.String(UInt64.random(in: 0...UInt64.max))
            let directory = File.Directory(try File.Path(validating: path))
            let store = Picture.Store.cpu(directory)
            func key(_ take: Motion.Take) -> Picture.Store.Key? {
                store.key(Picture(take, at: .zero), width: first.width, height: first.height, over: Picture.Color.black.pixel, form: "Motion.Pixel")
            }
            let kept = try #require(key(first))
            #expect(key(second) == kept)
            #expect(key(changed) != kept)
            for take in [first, second, changed] {
                let frames = Motion.Hosting.Picture.Frames(width: first.width, height: first.height, workers: 1, store: store) { _ in Picture(take, at: .zero) }
                #expect(try await frames.rasters([0]) == (try take.frames.map { try $0.raster() }))
            }
            let entries = try FileManager.default.contentsOfDirectory(atPath: path).filter { $0.hasSuffix(".entry") }
            #expect(entries.count == 2)
        }

        @Test func `a frame keys a picture by its size and digest, never by its pixels`() throws {
            let frame = Motion.Take.Frame(try Self.raster(seed: 2, width: 200, height: 100))
            #expect(Mirror(reflecting: frame).children.map(\.label) == ["width", "height", "digest", "pixels"])
            let bytes = try #require(Swift.Mirror.bytes(of: Picture(frame)))
            #expect(bytes.count < 4 * 200 * 100 / 10)
        }

        @Test func `a take read from its written form draws in a reel as the take it was written from, pixel for pixel`() async throws {
            let take = try Self.take([0, 1, 0, 2], rate: .ntsc)
            let read = try Motion.Take(written: take.written())
            let reel = Motion.Reel<Swift.String>(
                width: take.width,
                height: take.height,
                rate: .ntsc,
                parts: [.init("take", frames: 4) { frame in Picture(read, at: frame.time) }]
            )
            #expect(Picture(read, at: .zero) == Picture(take, at: .zero))
            let drawn = try await reel.hosting(workers: 2).rasters([3, 0, 2, 1])
            #expect(drawn == (try [3, 0, 2, 1].map { try take.frames[$0].raster() }))
        }

        @Test func `a frame whose pixels cannot be read fails the frame drawing it`() async throws {
            let take = try Self.take([4])
            var bytes = try take.written()
            bytes[60] = Byte(bitPattern: ~bytes[60].bitPattern)
            let read = try Motion.Take(written: bytes)
            #expect(throws: Motion.Take.Error.damaged(0)) { try read.frames[0].raster() }
            let frames = Motion.Hosting.Picture.Frames(width: take.width, height: take.height, workers: 1) { _ in Picture(read, at: .zero) }
            await #expect(throws: Motion.Hosting.Picture.Frames.Error.renderer(.drawing(.init(Motion.Take.Error.damaged(0))), at: 0)) {
                try await frames.rasters([0])
            }
        }
    }
#endif
