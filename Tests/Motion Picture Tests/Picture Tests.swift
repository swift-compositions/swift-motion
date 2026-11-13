#if Picture
    import Foundation
    import Motion
    import Motion_Encoding
    import Motion_Picture
    import Picture
    import Test_Apple
    import Testing
    import Witnesses

    @Suite(.deadline(.seconds(180))) struct `Picture Tests` {
        static func rectangle(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ color: Picture.Color) -> Picture.Element {
            let corners: [Picture.Plane.Point<2>] = [.init([x, y]), .init([x + width, y]), .init([x + width, y + height]), .init([x, y + height])]
            let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { start, end in
                Picture.Plane.Path.Segment.line(.init(start: start, end: end))
            }
            let path = Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
            return .shape(Picture.Shape(path, fill: .init(.solid(color))))
        }

        static func bytes(_ pixel: Motion.Pixel) -> [UInt8] { [pixel.red, pixel.green, pixel.blue, pixel.alpha] }

        @Test func `nothing is a clear pixel, opaque black and white are themselves, and every opaque grey of sRGB comes back as its own level`() {
            #expect(Self.bytes(Motion.Pixel(linear: 0, green: 0, blue: 0, alpha: 0)) == [0, 0, 0, 0])
            #expect(Self.bytes(Motion.Pixel(linear: 0, green: 0, blue: 0, alpha: 1)) == [0, 0, 0, 255])
            #expect(Self.bytes(Motion.Pixel(linear: 1, green: 1, blue: 1, alpha: 1)) == [255, 255, 255, 255])
            let wrong = (0...255).filter { level in
                Self.bytes(Motion.Pixel(Picture.Color(gray: Float(level) / 255).pixel)) != [UInt8(level), UInt8(level), UInt8(level), 255]
            }
            #expect(wrong.isEmpty, "greys that came back as another level: \(wrong)")
        }

        @Test func `each colour is its own channel, encoded from linear light: linear 0.5 is sRGB level 188`() {
            #expect(Self.bytes(Motion.Pixel(linear: 0.5, green: 0, blue: 0, alpha: 1)) == [188, 0, 0, 255])
            #expect(Self.bytes(Motion.Pixel(linear: 0, green: 0.5, blue: 0, alpha: 1)) == [0, 188, 0, 255])
            #expect(Self.bytes(Motion.Pixel(linear: 0, green: 0, blue: 0.5, alpha: 1)) == [0, 0, 188, 255])
        }

        @Test func `a colour under half alpha is encoded as its own colour and then halved: full red at half alpha is 128, 0, 0, 128`() {
            #expect(Self.bytes(Motion.Pixel(Picture.Color(red: 1, green: 0, blue: 0, alpha: 0.5).pixel)) == [128, 0, 0, 128])
            // Linear 0.25 under alpha 0.5 is the colour linear 0.5, sRGB 0.7354, halved: level 94.
            #expect(Self.bytes(Motion.Pixel(linear: 0.25, green: 0, blue: 0, alpha: 0.5)) == [94, 0, 0, 128])
        }

        @Test func `light brighter than white is white, less than none is none, and what is not a number is nothing`() {
            #expect(Self.bytes(Motion.Pixel(linear: 4, green: 9, blue: .infinity, alpha: 1)) == [255, 255, 255, 255])
            #expect(Self.bytes(Motion.Pixel(linear: -1, green: -0.5, blue: -.infinity, alpha: 1)) == [0, 0, 0, 255])
            #expect(Self.bytes(Motion.Pixel(linear: .nan, green: .nan, blue: .nan, alpha: 1)) == [0, 0, 0, 255])
            #expect(Self.bytes(Motion.Pixel(linear: 1, green: 1, blue: 1, alpha: .nan)) == [0, 0, 0, 0])
            #expect(Self.bytes(Motion.Pixel(linear: 1, green: 1, blue: 1, alpha: 7)) == [255, 255, 255, 255])
            #expect(Self.bytes(Motion.Pixel(linear: 1, green: 1, blue: 1, alpha: -1)) == [0, 0, 0, 0])
        }

        @Test func `no colour comes out above its alpha, whatever goes in`() {
            let values: [Float] = [-1, 0, 0.001, 0.0019, 0.002, 0.1, 0.25, 0.3333, 0.5, 0.75, 0.999, 1, 1.5, .infinity, .nan]
            var above = 0
            for alpha in values {
                for colour in values {
                    let pixel = Motion.Pixel(linear: colour, green: colour * 0.5, blue: colour * alpha, alpha: alpha)
                    if Motion.Pixel(blue: pixel.blue, green: pixel.green, red: pixel.red, alpha: pixel.alpha) == nil { above += 1 }
                }
            }
            #expect(above == 0)
        }

        @Test func `an empty picture is a frame of the background at the size asked, black unless another is given`() throws {
            let black = try Motion.Hosting.Picture.raster(.empty, width: 4, height: 3)
            #expect(black.width == 4 && black.height == 3)
            #expect(black.pixels.allSatisfy { Self.bytes($0) == [0, 0, 0, 255] })
            let white = try Motion.Hosting.Picture.raster(.empty, width: 2, height: 2, over: .white)
            #expect(white.pixels.allSatisfy { Self.bytes($0) == [255, 255, 255, 255] })
            let clear = try Motion.Hosting.Picture.raster(.empty, width: 2, height: 2, over: .clear)
            #expect(clear.pixels.allSatisfy { Self.bytes($0) == [0, 0, 0, 0] })
        }

        @Test func `a picture's point is the frame's position, the first row on top: a red rectangle fills exactly its pixels`() throws {
            let picture: Picture = [Self.rectangle(1, 0, 2, 2, Picture.Color(red: 1, green: 0, blue: 0))]
            let frame = try Motion.Hosting.Picture.raster(picture, width: 4, height: 3, over: .white)
            let red: [UInt8] = [255, 0, 0, 255]
            let white: [UInt8] = [255, 255, 255, 255]
            #expect(
                frame.pixels.map(Self.bytes) == [
                    white, red, red, white,
                    white, red, red, white,
                    white, white, white, white,
                ]
            )
        }

        @Test func `the renderer is the one in the current context, its failure is thrown as it is, and equal pictures give equal frames`() throws {
            let picture: Picture = [Self.rectangle(0.25, 0.5, 2.5, 1.75, Picture.Color(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.7))]
            #expect(try Motion.Hosting.Picture.raster(picture, width: 4, height: 3) == Motion.Hosting.Picture.raster(picture, width: 4, height: 3))
            #expect(throws: Picture.Renderer.Error.absent) {
                try withWitnesses {
                    $0[Picture.Renderer.self] = .absent
                } operation: { () throws(Picture.Renderer.Error) in
                    _ = try Motion.Hosting.Picture.raster(picture, width: 4, height: 3)
                }
            }
            #expect(try Motion.Hosting.Picture.raster(picture, width: 4, height: 3).width == 4)
        }

        @Test func `thirty drawn frames are written as a movie of thirty frames at their size`() async throws {
            let url = FileManager.default.temporaryDirectory.appending(path: "motion-picture-first-clip.mp4")
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            var failure: Picture.Renderer.Error?
            try await Motion.Encoding(width: 320, height: 180, rate: .thirty).write(frames: 30, to: url) { index in
                let step = Double(Int(exactly: index) ?? 0)
                let picture: Picture = [
                    Self.rectangle(0, 0, 320, 180, Picture.Color(red: 0.96, green: 0.94, blue: 0.9)),
                    Self.rectangle(20 + step * 8, 60, 60, 60, Picture.Color(red: 0.85, green: 0.35, blue: 0.2)),
                    Self.rectangle(250 - step * 6, 30 + step * 2, 40, 40, Picture.Color(red: 0.1, green: 0.2, blue: 0.5, alpha: 0.6)),
                ]
                do throws(Picture.Renderer.Error) {
                    return try Motion.Hosting.Picture.raster(picture, width: 320, height: 180)
                } catch {
                    failure = error
                    return nil
                }
            }
            #expect(failure == nil)
            let written = try await Motion.Encoding.Inspection(of: url)
            #expect(written.frames == 30)
            #expect(written.width == 320 && written.height == 180)
        }
    }
#endif
