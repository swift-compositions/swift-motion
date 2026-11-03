import Motion
import Motion_Cache
import SwiftUI
import Testing

@MainActor @Suite struct `Cache Tests` {
    static func card(_ shade: Double) -> some View {
        ZStack {
            Color.white
            RoundedRectangle(cornerRadius: 12).fill(Color(white: shade)).frame(width: 120, height: 80).shadow(radius: 8)
            Text("Birdwatch").font(.system(size: 18, weight: .semibold))
        }
    }

    @Test func `the same view always renders the same raster, at the size asked`() throws {
        let first = try #require(Hosting.Cache.raster(Self.card(0.4), width: 320, height: 180))
        let second = try #require(Hosting.Cache.raster(Self.card(0.4), width: 320, height: 180))
        #expect(first.width == 320 && first.height == 180)
        #expect(first == second)
        #expect(Render.check(0..<3) { _ in Hosting.Cache.raster(Self.card(0.4), width: 320, height: 180) ?? second } == .deterministic)
    }

    @Test func `a view's own state starts fresh in every frame`() throws {
        let first = try #require(Hosting.Cache.raster(Remembering(shade: 0.1), width: 320, height: 180))
        let later = try #require(Hosting.Cache.raster(Remembering(shade: 0.9), width: 320, height: 180))
        Hosting.Cache.forget()
        let alone = try #require(Hosting.Cache.raster(Remembering(shade: 0.9), width: 320, height: 180))
        #expect(first != later)
        #expect(later == alone)
    }

    @Test func `a raster made into an image and back is the same raster`() throws {
        let raster = try #require(Hosting.Cache.raster(Self.card(0.4), width: 320, height: 180))
        let image = try #require(raster.image)
        #expect(Raster(image: image) == raster)
    }
}
