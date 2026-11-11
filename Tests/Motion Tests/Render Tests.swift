import Motion
import Testing

@Suite struct `Render Tests` {
    final class Memory: @unchecked Sendable { var count = 0 }

    static func pixel(_ red: UInt8) throws(Motion.Pixel.Error) -> Raster<Motion.Pixel> {
        try Raster<Motion.Pixel>(width: 1, height: 1, bytes: [red, 0, 0, 255])
    }

    /// One-pixel rasters whose red is their position.
    static func shades() throws(Motion.Pixel.Error) -> [Raster<Motion.Pixel>] {
        try (UInt8(0)...9).map { red throws(Motion.Pixel.Error) in try pixel(red) }
    }

    @Test func `the render contract catches a renderer that remembers the previous frame`() throws {
        let shades = try Self.shades()
        let memory = Memory()
        let honest = Motion.Render.check(first: 3) { frame in shades[Int(bitPattern: frame)] }
        let remembering = Motion.Render.check(first: 3) { _ in
            memory.count += 1
            return shades[memory.count]
        }
        #expect(honest == .deterministic)
        let psnr = try #require(shades[1].psnr(against: shades[2]))
        #expect(remembering == .varies(frame: 0, psnr: psnr))
    }

    @Test func `the render contract reports a frame whose size changes between renders`() throws {
        let shades = try Self.shades()
        let memory = Memory()
        let resizing = Motion.Render.check(first: 3) { _ in
            memory.count += 1
            return memory.count == 1 ? shades[0] : Raster<Motion.Pixel>(width: 0, height: 0, repeating: shades[0].pixels[0])
        }
        #expect(resizing == .resized(frame: 0))
    }

    @Test func `the check asks for exactly the frames it is given, each twice, and names the one that varies`() throws {
        let shades = try Self.shades()
        let memory = Memory()
        var asked: [Ordinal] = []
        let verdict = Motion.Render.check([4, 7, 9]) { frame in
            asked.append(frame)
            memory.count += frame == 7 ? 1 : 0
            return shades[memory.count]
        }
        #expect(asked == [4, 4, 7, 7])
        let psnr = try #require(shades[1].psnr(against: shades[2]))
        #expect(verdict == .varies(frame: 7, psnr: psnr))
        var counted: [Ordinal] = []
        let steady = Motion.Render.check(first: 3) { frame in
            counted.append(frame)
            return shades[0]
        }
        #expect(steady == .deterministic)
        #expect(counted == [0, 0, 1, 1, 2, 2])
    }
}
