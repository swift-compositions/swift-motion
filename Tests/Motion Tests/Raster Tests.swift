import Motion
import Testing

@Suite struct `Raster Tests` {
    @Test func `a raster equals another with the same pixels whatever its row padding`() throws {
        let tight = try Raster(width: 1, height: 2, bytes: [10, 20, 30, 255, 0, 0, 0, 0])
        let padded = try Raster(width: 1, height: 2, stride: 8, bytes: [10, 20, 30, 255, 9, 9, 9, 9, 0, 0, 0, 0, 7, 7, 7, 7])
        #expect(tight == padded)
        #expect(padded.packed == tight.bytes)
        #expect(Raster.psnr(tight, padded) == .infinity)
    }

    @Test func `a raster refuses a colour brighter than its alpha, or the wrong size`() {
        #expect(throws: Raster.Error.premultiplied(x: 0, y: 0)) { try Raster(width: 1, height: 1, bytes: [200, 0, 0, 100]) }
        #expect(throws: Raster.Error.size(3, needed: 4)) { try Raster(width: 1, height: 1, bytes: [0, 0, 0]) }
        #expect(throws: Raster.Error.stride(3, needed: 4)) { try Raster(width: 1, height: 1, stride: 3, bytes: [0, 0, 0]) }
    }

    @Test func `PSNR of one channel off by one in 1920x1080 is 116.07 dB, alpha aside`() throws {
        var bytes = [UInt8](repeating: 255, count: 1920 * 1080 * 4)
        let a = try Raster(width: 1920, height: 1080, bytes: bytes)
        bytes[0] = 254
        let b = try Raster(width: 1920, height: 1080, bytes: bytes)
        #expect(abs(Raster.psnr(a, b) - 116.07) < 0.01, "\(Raster.psnr(a, b))")
    }
}
