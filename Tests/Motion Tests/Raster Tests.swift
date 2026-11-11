import Motion
import Testing

@Suite struct `Raster Tests` {
    @Test func `a raster of frame pixels drops row padding, so rasters read at different strides are equal`() throws {
        let tight = try Raster<Frame.Pixel>(width: 1, height: 2, bytes: [10, 20, 30, 255, 0, 0, 0, 0])
        let padded = try Raster<Frame.Pixel>(width: 1, height: 2, stride: 8, bytes: [10, 20, 30, 255, 9, 9, 9, 9, 0, 0, 0, 0, 7, 7, 7, 7])
        #expect(tight == padded)
        #expect(padded.bytes == [10, 20, 30, 255, 0, 0, 0, 0])
        #expect(padded.width == 1 && padded.height == 2)
        #expect(padded[x: 0, y: 0] == Frame.Pixel(blue: 10, green: 20, red: 30, alpha: 255))
        #expect(Raster<Frame.Pixel>.psnr(tight, padded) == Double.infinity)
    }

    @Test func `a frame pixel is never brighter than its alpha, and bytes that say otherwise or have the wrong size are refused`() {
        #expect(Frame.Pixel(blue: 200, green: 0, red: 0, alpha: 100) == nil)
        #expect(Frame.Pixel(blue: 100, green: 100, red: 100, alpha: 100) != nil)
        #expect(throws: Frame.Pixel.Error.premultiplied(x: 0, y: 0)) { try Raster<Frame.Pixel>(width: 1, height: 1, bytes: [200, 0, 0, 100]) }
        #expect(throws: Frame.Pixel.Error.premultiplied(x: 1, y: 1)) {
            try Raster<Frame.Pixel>(width: 2, height: 2, stride: 12, bytes: [0, 0, 0, 0, 0, 0, 0, 0, 9, 9, 9, 9] + [0, 0, 0, 0, 0, 0, 90, 80, 9, 9, 9, 9])
        }
        #expect(throws: Frame.Pixel.Error.size(3, needed: 4)) { try Raster<Frame.Pixel>(width: 1, height: 1, bytes: [0, 0, 0]) }
        #expect(throws: Frame.Pixel.Error.stride(3, needed: 4)) { try Raster<Frame.Pixel>(width: 1, height: 1, stride: 3, bytes: [0, 0, 0]) }
        #expect(throws: Frame.Pixel.Error.size(0, needed: 0)) { try Raster<Frame.Pixel>(width: -1, height: 1, bytes: []) }
    }

    @Test func `the top rows of a raster are its first rows`() throws {
        let raster = try Raster<Frame.Pixel>(width: 1, height: 3, stride: 8, bytes: [1, 1, 1, 255, 7, 7, 7, 7, 2, 2, 2, 255, 7, 7, 7, 7, 3, 3, 3, 255, 7, 7, 7, 7])
        #expect(raster.top(2) == (try Raster<Frame.Pixel>(width: 1, height: 2, bytes: [1, 1, 1, 255, 2, 2, 2, 255])))
        #expect(raster.top(3) == raster)
        #expect(raster.top(0).isEmpty)
    }

    @Test func `PSNR of one channel off by one in 1920x1080 is 116.07 dB, alpha aside`() throws {
        var bytes = [UInt8](repeating: 255, count: 1920 * 1080 * 4)
        let a = try Raster<Frame.Pixel>(width: 1920, height: 1080, bytes: bytes)
        bytes[0] = 254
        let b = try Raster<Frame.Pixel>(width: 1920, height: 1080, bytes: bytes)
        let psnr = try #require(Raster<Frame.Pixel>.psnr(a, b))
        #expect(abs(psnr - 116.07) < 0.01, "\(psnr)")
    }

    @Test func `PSNR of rasters of different sizes is nil, not a trap`() throws {
        let one = try Raster<Frame.Pixel>(width: 1, height: 1, bytes: [0, 0, 0, 255])
        let two = try Raster<Frame.Pixel>(width: 2, height: 1, bytes: [0, 0, 0, 255, 0, 0, 0, 255])
        #expect(Raster<Frame.Pixel>.psnr(one, two) == nil)
        #expect(Raster<Frame.Pixel>.psnr(one, one.top(0)) == nil)
    }

    @Test func `the molecule's operations apply to a frame's raster`() throws {
        let raster = try Raster<Frame.Pixel>(width: 2, height: 1, bytes: [0, 0, 0, 255, 100, 100, 100, 255])
        let alphas = raster.map(\.alpha)
        #expect(alphas.pixels == [255, 255])
        #expect(raster.reduce(0) { $0 + Int($1.red) } == 100)
    }
}
