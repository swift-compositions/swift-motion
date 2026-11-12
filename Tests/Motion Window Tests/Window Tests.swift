import AppKit
import CoreGraphics
import Motion
import Motion_Cache
import SwiftUI
import Testing

@testable import Motion_Window

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
        let first = try #require(await Motion.Hosting.Window.raster(Self.card(0.4), width: 320, height: 180))
        let second = try #require(await Motion.Hosting.Window.raster(Self.card(0.4), width: 320, height: 180))
        #expect(first.width == 320 && first.height == 180)
        #expect(first == second)
    }

    @Test func `each capture shows its own frame, never the one before`() async throws {
        let shades = [0.0, 1.0, 0.2, 0.8, 0.5, 0.0, 1.0, 0.3]
        var captured: [Raster<Motion.Pixel>] = []
        for shade in shades {
            captured.append(try #require(await Motion.Hosting.Window.raster(Color(white: shade), width: 64, height: 36)))
        }
        for (raster, shade) in zip(captured, shades) {
            let expected = UInt8((shade * 255).rounded())
            #expect(abs(Int(raster.bytes[0]) - Int(expected)) <= 1, "shade \(shade) captured as \(raster.bytes[0])")
        }
    }

    @Test func `overlapping captures each get their own picture`() async throws {
        let shades = [0.0, 1.0, 0.5, 0.2, 0.8, 0.4]
        let captures = shades.map { shade in Task { @MainActor in await Motion.Hosting.Window.raster(Color(white: shade), width: 64, height: 36) } }
        for (shade, capture) in zip(shades, captures) {
            let raster = await capture.value
            let expected = Int((shade * 255).rounded())
            #expect(raster.map { abs(Int($0.bytes[0]) - expected) <= 1 } == true, "shade \(shade) captured as \(raster.map { "\($0.bytes[0])" } ?? "nothing")")
        }
    }

    @Test func `captures of one size reuse one window`() async throws {
        Motion.Hosting.Window.forget()
        let before = Motion.Hosting.Window.opened
        for shade in [0.2, 0.5, 0.8] { _ = try #require(await Motion.Hosting.Window.raster(Color(white: shade), width: 64, height: 36)) }
        #expect(Motion.Hosting.Window.opened - before == 1)
    }

    @Test func `the picture is captured pixel for pixel: alternate one-pixel rows come back exact, to the last row`() async throws {
        let rows = VStack(spacing: 0) {
            ForEach(0..<90, id: \.self) { row in Color(white: row % 2 == 0 ? 0 : 1).frame(height: 1) }
        }
        let raster = try #require(await Motion.Hosting.Window.raster(rows, width: 160, height: 90))
        let bytes = raster.bytes
        let wrong = (0..<90).filter { row in bytes[(row * 640)..<((row + 1) * 640)].enumerated().contains { $0.offset % 4 != 3 && $0.element != (row % 2 == 0 ? 0 : 255) } }
        #expect(wrong.isEmpty, "rows not exact: \(wrong)")
    }

    @Test func `a size that is not whole points is refused, and at one pixel per point every size is whole`() async {
        let scale = Int(NSScreen.main?.backingScaleFactor ?? 1)
        let odd = await Motion.Hosting.Window.raster(Color.white, width: 161, height: 90)
        #expect((odd == nil) == (scale > 1), "at \(scale)x")
    }

    @Test func `a size the window server cannot be told is nil, not a trap`() async {
        #expect(await Motion.Hosting.Window.raster(Color.white, width: .max, height: 90) == nil)
        #expect(await Motion.Hosting.Window.raster(Color.white, width: 160, height: Cardinal(UInt(Int32.max) + 1)) == nil)
    }

    @Test func `a live animation is frozen, so it captures the same raster every time`() async throws {
        let spinning = ZStack {
            Color.white
            ProgressView().controlSize(.large)
        }
        let first = try #require(await Motion.Hosting.Window.raster(spinning, width: 160, height: 90))
        try await Task.sleep(for: .milliseconds(300))
        let later = try #require(await Motion.Hosting.Window.raster(spinning, width: 160, height: 90))
        #expect(first == later)
    }

    @Test func `a view's own state starts fresh in every frame`() async throws {
        let first = try #require(await Motion.Hosting.Window.raster(Remembering(shade: 0.1), width: 320, height: 180))
        let later = try #require(await Motion.Hosting.Window.raster(Remembering(shade: 0.9), width: 320, height: 180))
        Motion.Hosting.Window.forget()
        let alone = try #require(await Motion.Hosting.Window.raster(Remembering(shade: 0.9), width: 320, height: 180))
        #expect(first != later)
        #expect(later == alone)
    }

    @Test func `a live capture counts only when it has the picture's size and its band spells the frame's own number`() throws {
        let digits = Motion.Hosting.Window.digits(27)
        let colours: [[UInt8]] = [[0, 0, 0, 255], [0, 0, 255, 255], [0, 255, 0, 255], [255, 0, 0, 255]]
        let band = (0..<64).flatMap { x in colours[digits[x / 4]] }
        let fenced = try Raster<Motion.Pixel>(width: 64, height: 10, bytes: [UInt8](repeating: 255, count: 64 * 8 * 4) + band + band)
        let image = try #require(fenced.image)
        #expect(Motion.Hosting.Live.shows(image, number: 27, width: 64, height: 8, scale: 2))
        #expect(!Motion.Hosting.Live.shows(image, number: 26, width: 64, height: 8, scale: 2))
        #expect(!Motion.Hosting.Live.shows(image, number: 27 + 1 << 30, width: 64, height: 8, scale: 2))
        #expect(!Motion.Hosting.Live.shows(image, number: 27, width: 64, height: 6, scale: 2))
        #expect(!Motion.Hosting.Live.shows(image, number: 27, width: 32, height: 8, scale: 2))
        let taller = try Raster<Motion.Pixel>(width: 64, height: 12, bytes: fenced.bytes + band + band)
        #expect(!Motion.Hosting.Live.shows(try #require(taller.image), number: 27, width: 64, height: 8, scale: 2))
        let wider = try Raster<Motion.Pixel>(width: 128, height: 10, bytes: (0..<10).flatMap { row in Array(fenced.bytes[(row * 256)..<((row + 1) * 256)]) + [UInt8](repeating: 255, count: 256) })
        #expect(!Motion.Hosting.Live.shows(try #require(wider.image), number: 27, width: 64, height: 8, scale: 2))
    }

    /// A capture of a 64 by 8 picture of one shade, with the band below it spelling `number`.
    static func capture(shade: UInt8, number: Int) -> CGImage? {
        let digits = Motion.Hosting.Window.digits(number)
        let colours: [[UInt8]] = [[0, 0, 0, 255], [0, 0, 255, 255], [0, 255, 0, 255], [255, 0, 0, 255]]
        let band: [UInt8] = (0..<64).flatMap { x in colours[digits[x / 4]] }
        let picture: [UInt8] = (0..<(64 * 8)).flatMap { _ in [shade, shade, shade, 255] }
        do throws(Motion.Pixel.Error) {
            return try Raster<Motion.Pixel>(width: 64, height: 10, bytes: picture + band + band).image
        } catch {
            return nil
        }
    }

    @Test func `a live frame is the first capture that shows its number and is followed by the same picture; captures that never agree or never show it fail`() async throws {
        var shots = [(10, 6), (20, 7), (30, 7), (40, 7), (40, 7), (50, 7)].compactMap { Self.capture(shade: $0.0, number: $0.1) }
        #expect(shots.count == 6)
        let settled = try await Motion.Hosting.Live.settled(3, number: 7, width: 64, height: 8, scale: 2, between: .zero) {
            shots.isEmpty ? nil : shots.removeFirst()
        } reason: {
            "none"
        }
        #expect(settled.width == 64 && settled.height == 8)
        #expect(settled.pixels.allSatisfy { $0.red == 40 })
        #expect(shots.count == 1)
        var shade: UInt8 = 0
        await #expect(throws: Motion.Hosting.Live.Error.unsettled(frame: 3)) {
            _ = try await Motion.Hosting.Live.settled(3, number: 7, width: 64, height: 8, scale: 2, between: .zero) {
                shade += 1
                return Self.capture(shade: shade, number: 7)
            } reason: {
                "none"
            }
        }
        #expect(shade == 80)
        let stale = Self.capture(shade: 5, number: 6)
        await #expect(throws: Motion.Hosting.Live.Error.capture(frame: 3, "the reason")) {
            _ = try await Motion.Hosting.Live.settled(3, number: 7, width: 64, height: 8, scale: 2, between: .zero) {
                stale
            } reason: {
                "the reason"
            }
        }
    }
}
