import Motion
import Testing

@Suite struct `Render Tests` {
    final class Memory: @unchecked Sendable { var count = 0 }

    static func pixel(_ red: UInt8) -> Raster {
        // swift-linter:disable:next try optional
        // REASON: an opaque pixel is always a valid raster.
        try! Raster(width: 1, height: 1, bytes: [red, 0, 0, 255])
    }

    @Test func `the render contract catches a renderer that remembers the previous frame`() throws {
        let memory = Memory()
        let honest = Render.check(0..<3) { frame in Self.pixel(UInt8(frame)) }
        let remembering = Render.check(0..<3) { _ in
            memory.count += 1
            return Self.pixel(UInt8(memory.count))
        }
        #expect(honest == .deterministic)
        let psnr = try #require(Raster.psnr(Self.pixel(1), Self.pixel(2)))
        #expect(remembering == .varies(frame: 0, psnr: psnr))
    }

    @Test func `the render contract reports a frame whose size changes between renders`() {
        let memory = Memory()
        let resizing = Render.check(0..<3) { _ in
            memory.count += 1
            return memory.count == 1 ? Self.pixel(0) : Self.pixel(0).top(0)
        }
        #expect(resizing == .resized(frame: 0))
    }

    @Test func `frames that finish out of order are delivered in order, each as soon as it can be`() {
        var ordered = Render.Ordered<String>()
        #expect(ordered.arrive(2, "c") == [])
        #expect(ordered.arrive(0, "a") == ["a"])
        #expect(ordered.arrive(1, "b") == ["b", "c"])
        #expect(ordered.arrive(3, "d") == ["d"])
    }
}
