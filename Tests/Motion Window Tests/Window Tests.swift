import AppKit
import CoreGraphics
import Motion
import Motion_Window
import SwiftUI
import Testing

/// These tests capture the screen, so they run only where Screen Recording is granted.
@MainActor @Suite(.enabled(if: CGPreflightScreenCaptureAccess(), "needs Screen Recording permission"), .serialized)
struct `Window Tests` {
    static func card(_ shade: Double) -> some View {
        ZStack {
            Color.white
            RoundedRectangle(cornerRadius: 12).fill(Color(white: shade)).frame(width: 120, height: 80).shadow(radius: 8)
            Text("Birdwatch").font(.system(size: 18, weight: .semibold))
        }
    }

    @Test func `the same view always captures the same raster, at the size asked`() async throws {
        let first = try #require(await Hosting.Window.raster(Self.card(0.4), width: 320, height: 180))
        let second = try #require(await Hosting.Window.raster(Self.card(0.4), width: 320, height: 180))
        #expect(first.width == 320 && first.height == 180)
        #expect(first == second)
    }

    @Test func `each capture shows its own frame, never the one before`() async throws {
        let shades = [0.0, 1.0, 0.2, 0.8, 0.5, 0.0, 1.0, 0.3]
        var captured: [Raster] = []
        for shade in shades {
            captured.append(try #require(await Hosting.Window.raster(Color(white: shade), width: 64, height: 36)))
        }
        for (raster, shade) in zip(captured, shades) {
            let expected = UInt8((shade * 255).rounded())
            #expect(abs(Int(raster.bytes[0]) - Int(expected)) <= 1, "shade \(shade) captured as \(raster.bytes[0])")
        }
    }

    @Test func `the picture is captured pixel for pixel: alternate one-pixel rows come back exact, to the last row`() async throws {
        let rows = VStack(spacing: 0) {
            ForEach(0..<90, id: \.self) { row in Color(white: row % 2 == 0 ? 0 : 1).frame(height: 1) }
        }
        let raster = try #require(await Hosting.Window.raster(rows, width: 160, height: 90))
        let wrong = (0..<90).filter { row in raster.row(row).enumerated().contains { $0.offset % 4 != 3 && $0.element != (row % 2 == 0 ? 0 : 255) } }
        #expect(wrong.isEmpty, "rows not exact: \(wrong)")
    }

    @Test func `a size that is not whole points is refused, and at one pixel per point every size is whole`() async {
        let scale = Int(NSScreen.main?.backingScaleFactor ?? 1)
        let odd = await Hosting.Window.raster(Color.white, width: 161, height: 90)
        #expect((odd == nil) == (scale > 1), "at \(scale)x")
    }

    @Test func `a live animation is frozen, so it captures the same raster every time`() async throws {
        let spinning = ZStack {
            Color.white
            ProgressView().controlSize(.large)
        }
        let first = try #require(await Hosting.Window.raster(spinning, width: 160, height: 90))
        try await Task.sleep(for: .milliseconds(300))
        let later = try #require(await Hosting.Window.raster(spinning, width: 160, height: 90))
        #expect(first == later)
    }

    @Test func `a view's own state starts fresh in every frame`() async throws {
        let first = try #require(await Hosting.Window.raster(Remembering(shade: 0.1), width: 320, height: 180))
        let later = try #require(await Hosting.Window.raster(Remembering(shade: 0.9), width: 320, height: 180))
        Hosting.Window.forget()
        let alone = try #require(await Hosting.Window.raster(Remembering(shade: 0.9), width: 320, height: 180))
        #expect(first != later)
        #expect(later == alone)
    }
}
