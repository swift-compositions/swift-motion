import Motion
import Testing

@Suite struct `Render Tests` {
    final class Memory: @unchecked Sendable { var count = 0 }

    static func pixel(_ red: UInt8) -> Raster<Motion.Pixel> {
        // swift-linter:disable:next try optional
        // REASON: an opaque pixel is always a valid raster.
        try! Raster<Motion.Pixel>(width: 1, height: 1, bytes: [red, 0, 0, 255])
    }

    @Test func `the render contract catches a renderer that remembers the previous frame`() throws {
        let memory = Memory()
        let honest = Motion.Render.check(0..<3) { frame in Self.pixel(UInt8(frame)) }
        let remembering = Motion.Render.check(0..<3) { _ in
            memory.count += 1
            return Self.pixel(UInt8(memory.count))
        }
        #expect(honest == .deterministic)
        let psnr = try #require(Self.pixel(1).psnr(against: Self.pixel(2)))
        #expect(remembering == .varies(frame: 0, psnr: psnr))
    }

    @Test func `the render contract reports a frame whose size changes between renders`() {
        let memory = Memory()
        let resizing = Motion.Render.check(0..<3) { _ in
            memory.count += 1
            return memory.count == 1 ? Self.pixel(0) : Raster<Motion.Pixel>(width: 0, height: 0, repeating: Self.pixel(0).pixels[0])
        }
        #expect(resizing == .resized(frame: 0))
    }
}
