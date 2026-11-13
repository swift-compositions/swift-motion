#if Picture
    import Byte
    import Foundation
    import Motion
    import Motion_Encoding
    import Motion_Picture
    import Picture
    import Test_Apple
    import Testing

    @Suite(.deadline(.seconds(180))) struct `Pairs Tests` {
        /// A movie of `frames` frames at 30 a second, 64 by 36, every pixel one opaque colour.
        static func movie(blue: UInt8, green: UInt8, red: UInt8, frames: Cardinal) async throws -> URL {
            let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            let pixel = try #require(Motion.Pixel(blue: blue, green: green, red: red, alpha: 255))
            let raster = Raster(width: 64, height: 36, repeating: pixel)
            try await Motion.Encoding(width: 64, height: 36, rate: .thirty).write(frames: frames, to: url) { _ in raster }
            return url
        }

        /// The pairs of two movies at some instants.
        static func pairs(_ reference: Motion.Decoding, _ other: Motion.Decoding, at instants: [Rational]) async throws -> [Motion.Pairs.Pair] {
            let left = try await reference.frames(at: instants)
            let right = try await other.frames(at: instants)
            return zip(instants, zip(left, right)).map { Motion.Pairs.Pair(time: $0, reference: $1.0, other: $1.1) }
        }

        /// Whether a working pixel is near an sRGB colour given in levels.
        static func near(_ pixel: Picture.Pixel, red: Float, green: Float, blue: Float) -> Bool {
            let color = Picture.Color(pixel)
            return abs(color.red * 255 - red) < 12 && abs(color.green * 255 - green) < 12 && abs(color.blue * 255 - blue) < 12
        }

        @Test func `the instants are every step from zero before the end, in sheets of a count`() throws {
            let tenth = try Rational(numerator: 1, denominator: 10)
            let sheets = Motion.Pairs.instants(every: tenth, before: try Rational(numerator: 1, denominator: 2), count: 2)
            #expect(sheets == [[0, tenth], [tenth * 2, tenth * 3], [tenth * 4]])
            #expect(Motion.Pairs.instants(every: tenth, before: 0, count: 2) == [])
        }

        @Test func `a sheet of two movies sets each pair side by side, two pairs to a row, and fills what a movie lacks`() async throws {
            let reference = try await Motion.Decoding(try await Self.movie(blue: 0, green: 0, red: 220, frames: 9))
            let other = try await Motion.Decoding(try await Self.movie(blue: 220, green: 0, red: 0, frames: 6))
            let tenth = try Rational(numerator: 1, denominator: 10)
            let pairs = try await Self.pairs(reference, other, at: [0, tenth, tenth * 2])
            #expect(pairs[2].reference != nil && pairs[2].other == nil)
            let layout = Motion.Pairs(width: 32, height: 18, columns: 2, gap: 4)
            let sheet = try layout.sheet(pairs)
            #expect(sheet.width == 140 && sheet.height == 40)
            let gray = Picture.Color(gray: 0.12)
            let tiles: [(x: UInt, y: UInt, red: Float, blue: Float)] = [(16, 9, 220, 0), (52, 9, 0, 220), (88, 9, 220, 0), (124, 9, 0, 220), (16, 31, 220, 0)]
            for tile in tiles {
                #expect(Self.near(sheet[x: Ordinal(tile.x), y: Ordinal(tile.y)], red: tile.red, green: 0, blue: tile.blue), "tile at \(tile.x), \(tile.y)")
            }
            #expect(sheet[x: 52, y: 31] == gray.pixel)
            #expect(sheet[x: 34, y: 9] == gray.pixel)
            let png = try layout.png(pairs)
            #expect(Array(png.prefix(4)) == [Byte](bitPatterns: [0x89, 0x50, 0x4E, 0x47] as [UInt8]))
        }

        @Test func `a label writes the instant in seconds with two decimals above its pair, in the font given`() async throws {
            #expect(Motion.Pairs.Label.text(0) == "0.00 s")
            #expect(Motion.Pairs.Label.text(try Rational(numerator: 247, denominator: 20)) == "12.35 s")
            #expect(Motion.Pairs.Label.text(try Rational(numerator: 1001, denominator: 30000)) == "0.03 s")
            let path = "/System/Library/Fonts/Supplemental/Arial.ttf"
            guard FileManager.default.fileExists(atPath: path) else { return }
            let font = [Byte](bitPatterns: [UInt8](try Data(contentsOf: URL(filePath: path))))
            let pixel = try #require(Motion.Pixel(blue: 0, green: 0, red: 0, alpha: 255))
            let black = Raster(width: 64, height: 36, repeating: pixel)
            let layout = Motion.Pairs(width: 64, height: 36, label: Motion.Pairs.Label(font: font, size: 16))
            let sheet = try layout.sheet([Motion.Pairs.Pair(time: 0, reference: black, other: black)])
            #expect(sheet.width == 136 && sheet.height == 56)
            let row = (0..<20).flatMap { y in (0..<136).map { x in sheet[x: Ordinal(UInt(x)), y: Ordinal(UInt(y))] } }
            #expect(row.contains { Picture.Color($0).red > 0.5 })
        }

        @Test func `a reel's frames at instants are the frames its hosting draws, and nothing past its end`() async throws {
            let reel = Motion.Reel<String>(width: 8, height: 6, rate: .thirty, over: .white, parts: [
                Motion.Reel<String>.Part("a", frames: 3) { frame in
                    [`Picture Tests`.rectangle(Double(Int(bitPattern: frame.position)), 1, 2, 2, .black)]
                }
            ])
            let tenth = try Rational(numerator: 1, denominator: 10)
            let shown = try await reel.frames(at: [try Rational(numerator: 1, denominator: 40), -tenth, tenth, try Rational(numerator: 1, denominator: 15)])
            let drawn = try await reel.hosting().rasters([0, 2])
            #expect(shown[0] == drawn[0])
            #expect(shown[1] == nil)
            #expect(shown[2] == nil)
            #expect(shown[3] == drawn[1])
        }
    }
#endif
