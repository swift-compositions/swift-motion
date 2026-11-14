#if Picture && canImport(AVFoundation)
    import CoreVideo
    import Foundation
    import Motion
    @testable import Motion_Encoding
    import Motion_Picture
    import Picture
    import Picture_CPU
    import Picture_Store
    import File_System
    import RFC_1951
    import Testing

    /// What the frame cache and the encoder cost on full-HD frames, printed and never asserted: wall times vary
    /// with the machine and its load. Run in release with `MOTION_TIMING=1 swift test -c release --enable-all-traits
    /// --filter "Timing Tests"`.
    @Suite(
        .serialized,
        .enabled(if: ProcessInfo.processInfo.environment["MOTION_TIMING"] != nil, "a measurement, run with MOTION_TIMING=1 in release")
    )
    struct `Timing Tests` {
        static let width: Cardinal = 1920
        static let height: Cardinal = 1080
        static let runs = 9

        /// The median of some runs of a body, in milliseconds.
        static func median(_ runs: Int = runs, _ body: () throws -> Void) rethrows -> Double {
            var times: [Double] = []
            for _ in 0..<runs {
                let start = ContinuousClock.now
                try body()
                let elapsed = ContinuousClock.now - start
                times.append(Double(elapsed.components.seconds) * 1e3 + Double(elapsed.components.attoseconds) / 1e15)
            }
            return times.sorted()[runs / 2]
        }

        static func print(_ line: Swift.String) {
            Swift.print("[timing] " + line)
        }

        static func ms(_ value: Double) -> Swift.String {
            "\((value * 100).rounded() / 100) ms"
        }

        static func ratio(_ whole: Int, _ part: Int) -> Swift.String {
            "\((Double(whole) / Double(part) * 10).rounded() / 10)"
        }

        /// A seeded generator, so every run draws the same frames.
        struct Noise {
            var state: UInt64
            mutating func next() -> Double {
                state ^= state << 13
                state ^= state >> 7
                state ^= state << 17
                return Double(state >> 11) / Double(1 << 53)
            }
        }

        static func polygon(_ corners: [Picture.Plane.Point<2>], _ paint: Picture.Paint) -> Picture.Element {
            let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { start, end in
                Picture.Plane.Path.Segment.line(.init(start: start, end: end))
            }
            let path = Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
            return .shape(Picture.Shape(path, fill: .init(paint)))
        }

        static func box(_ x: Double, _ y: Double, _ width: Double, _ height: Double, slant: Double = 0, _ paint: Picture.Paint) -> Picture.Element {
            let corners: [Picture.Plane.Point<2>] = [
                .init([x + slant, y]), .init([x + width + slant, y]), .init([x + width, y + height]), .init([x, y + height]),
            ]
            return polygon(corners, paint)
        }

        /// A frame like a film's: a gradient over the whole frame, a soft radial light, lines of slanted marks
        /// as small as type, and grain of thousands of small sprites.
        static func picture(_ index: Int) -> Picture {
            var noise = Noise(state: 0x9E37_79B9_7F4A_7C15 &+ UInt64(index) &* 0x1000_0001)
            let top = Picture.Color(red: 0.05, green: 0.08 + Float(index) / 100, blue: 0.2)
            let foot = Picture.Color(red: 0.4, green: 0.2, blue: 0.35)
            let start = Picture.Plane.Point<2>([0, 0])
            let end = Picture.Plane.Point<2>([400, 1080])
            var elements: [Picture.Element] = [
                box(0, 0, 1920, 1080, .linear(.init(from: start, to: end, Picture.Gradient(evenly: [top, foot]))))
            ]
            let center = Picture.Plane.Point<2>([1300 + Double(index) * 20, 400])
            let light = Picture.Gradient(evenly: [Picture.Color(red: 1, green: 0.8, blue: 0.5, alpha: 0.7), Picture.Color(red: 1, green: 0.8, blue: 0.5, alpha: 0)])
            elements.append(box(700, 0, 1220, 1080, .radial(.init(center: center, radius: 600, light))))
            let ink = Picture.Paint.solid(Picture.Color(red: 0.95, green: 0.93, blue: 0.88))
            for line in Array(0..<24) {
                var x = 120.0
                let y = 140.0 + Double(line) * 34
                while x < 1100 {
                    let wide = 6 + noise.next() * 10
                    elements.append(box(x, y, wide, 20, slant: 3, ink))
                    x += wide + 2 + (noise.next() < 0.15 ? 10 : 0)
                }
            }
            var grain: [Picture.Sprites.Sprite] = []
            for _ in 0..<30_000 {
                let point = Picture.Plane.Point<2>([noise.next() * 1920, noise.next() * 1080])
                let level = Float(noise.next() * 0.12)
                grain.append(.init(center: point, radius: 0.6 + noise.next() * 1.4, color: Picture.Color(red: level, green: level, blue: level)))
            }
            elements.append(.sprites(Picture.Sprites(grain)))
            return Picture(elements)
        }

        static func frames() async throws -> [Raster<Motion.Pixel>] {
            let frames = Motion.Hosting.Picture.Frames(width: width, height: height, picture: { picture(Int(bitPattern: $0)) })
            return try await frames.rasters([0, 1, 2])
        }

        @Test func `drawing, and a frame kept in and read back from the store`() async throws {
            let path = "/tmp/motion-timing-" + Swift.String(UInt64.random(in: 0...UInt64.max))
            let store = Picture.Store.cpu(File.Directory(try File.Path(validating: path)))
            let rasters = try await Self.frames()
            let one = Motion.Hosting.Picture.Frames(width: Self.width, height: Self.height, workers: 1, picture: { Self.picture(Int(bitPattern: $0)) })
            var drawing: [Double] = []
            for index in [0, 1, 2] {
                let start = ContinuousClock.now
                _ = try await one.rasters([Ordinal(UInt(index))])
                let elapsed = ContinuousClock.now - start
                drawing.append(Double(elapsed.components.seconds) * 1e3 + Double(elapsed.components.attoseconds) / 1e15)
            }
            Self.print("draw one frame on one thread: \(drawing.map(Self.ms))")
            for form in [Motion.Hosting.Picture.Frames.Form<Raster<Motion.Pixel>>.movie, .deflated] {
                let name = form.name?(0) ?? ""
                for (index, raster) in rasters.enumerated() {
                    let key = try #require(store.key(Self.picture(index), width: Self.width, height: Self.height, over: Picture.Color.black.pixel, form: name))
                    let bytes = Self.median { _ = form.bytes(raster) }
                    let kept = try #require(form.bytes(raster))
                    let keep = try Self.median { try store.keep(kept, for: key) }
                    let file = store.directory[try File.Path.Component(key.hex + ".entry")]
                    let read = try Self.median { _ = try file.read.bytes() }
                    let entry = try #require(store.bytes(for: key))
                    let fetch = Self.median { _ = store.bytes(for: key) }
                    let frame = Self.median { _ = form.frame(entry) }
                    #expect(form.frame(entry) == raster)
                    Self.print(
                        "\(name) frame \(index), \(kept.count) bytes: miss form.bytes \(Self.ms(bytes)) + store.keep \(Self.ms(keep)); hit file read \(Self.ms(read)), store.bytes \(Self.ms(fetch)) + form.frame \(Self.ms(frame))"
                    )
                }
            }
        }

        @Test func `the encoder's copy into a pixel buffer and the decoder's copy out of one`() async throws {
            let rasters = try await Self.frames()
            let attributes = CVPixelBufferCreationAttributes(
                pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
                size: CVImageSize(width: 1920, height: 1080),
                compatibility: [.cgBitmapContext, .cgImage]
            )
            var buffer = try CVMutablePixelBuffer(attributes)
            let copy = Self.median { Motion.Encoding.copy(rasters[0], into: &buffer) }
            var decoded: CVPixelBuffer?
            unsafe CVPixelBufferCreate(kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_32BGRA, nil, &decoded)
            let pixels = try #require(decoded)
            CVPixelBufferLockBaseAddress(pixels, [])
            let stride = CVPixelBufferGetBytesPerRow(pixels)
            if let base = unsafe CVPixelBufferGetBaseAddress(pixels) {
                rasters[0].pixels.withUnsafeBytes { source in
                    (0..<1080).forEach { row in
                        unsafe (base + row * stride).copyMemory(from: source.baseAddress! + row * 7680, byteCount: 7680)
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])
            let read = Self.median { _ = Motion.Encoding.raster(pixels) }
            #expect(Motion.Encoding.raster(pixels) == rasters[0])
            Self.print("encoder copy \(Self.ms(copy)); decoder raster \(Self.ms(read)) (stride \(stride))")
        }

        /// The movie form's pixels with each byte less the same byte of the pixel to its left, as PNG's Sub filter.
        static func sub(_ bytes: [Byte]) -> [Byte] {
            var out = bytes
            out.withUnsafeMutableBytes { target in
                var index = target.count
                while index > 4 + 16 {
                    index -= 1
                    unsafe target[index] = target[index] &- target[index - 4]
                }
            }
            return out
        }

        @Test func `the movie form compressed`() async throws {
            let form = Motion.Hosting.Picture.Frames.Form<Raster<Motion.Pixel>>.movie
            let rasters = try await Self.frames()
            for (index, raster) in rasters.enumerated() {
                let bytes = try #require(form.bytes(raster))
                let deflate = Self.median(5) { _ = RFC_1951.compress(bytes, level: .fast) }
                let packed = RFC_1951.compress(bytes, level: .fast)
                let inflate = try Self.median(5) { _ = try RFC_1951.decompress(packed) }
                #expect(try RFC_1951.decompress(packed) == bytes)
                let filtered = Self.sub(bytes)
                let subDeflate = Self.median(5) { _ = RFC_1951.compress(Self.sub(bytes), level: .fast) }
                let subPacked = RFC_1951.compress(filtered, level: .fast)
                let subInflate = try Self.median(5) { _ = try RFC_1951.decompress(subPacked) }
                Self.print(
                    "frame \(index): \(bytes.count) bytes; fast deflate \(Self.ms(deflate)) to \(packed.count) (\(Self.ratio(bytes.count, packed.count))x), inflate \(Self.ms(inflate)); with Sub filter \(Self.ms(subDeflate)) to \(subPacked.count) (\(Self.ratio(bytes.count, subPacked.count))x), inflate \(Self.ms(subInflate))"
                )
            }
        }

        @Test func `the store's key of a picture of 100,000 sprites`() throws {
            var noise = Noise(state: 42)
            var sprites: [Picture.Sprites.Sprite] = []
            for _ in 0..<100_000 {
                let point = Picture.Plane.Point<2>([noise.next() * 1920, noise.next() * 1080])
                sprites.append(.init(center: point, radius: 1 + noise.next() * 3, color: Picture.Color(red: Float(noise.next()), green: 0.5, blue: 0.9)))
            }
            let picture = Picture([.sprites(Picture.Sprites(sprites))])
            let store = Picture.Store.cpu(File.Directory(try File.Path(validating: "/tmp/motion-timing-key")))
            let key = Self.median { _ = store.key(picture, width: Self.width, height: Self.height, over: Picture.Color.black.pixel, form: "Motion.Pixel") }
            let bytes = 100_000 * MemoryLayout<Picture.Sprites.Sprite>.stride
            Self.print("key of 100,000 sprites (\(bytes) bytes of sprites): \(Self.ms(key))")
        }
    }
#endif
