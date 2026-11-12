import AppKit
import CoreGraphics
import Foundation
import Motion
import Motion_Window
import SwiftUI
import Testing

/// These tests capture the screen from the fixture process, so they run only where Screen Recording is granted.
@MainActor @Suite(.enabled(if: CGPreflightScreenCaptureAccess(), "needs Screen Recording permission"), .serialized, .timeLimit(.minutes(4)))
struct `Live Tests` {
    /// What the fixture measured for each frame: the bar's dark pixels, where the square starts, and a digest of the picture.
    static func frames(_ found: [String: [String]]) -> [[String]] {
        (found["frame"] ?? []).map { $0.split(separator: " ").map(String.init) }
    }

    @Test func `each frame advances the view's own animations by exactly one frame's duration, SwiftUI's and Core Animation's alike`() {
        let found = Fixture.run(["live", "120", "12"], inserting: true)
        let frames = Self.frames(found)
        #expect(found["error"] == nil && found["status"] == ["exit 0"], "\(found["error"] ?? []) \(found["status"] ?? []) \(found["stderr"] ?? [])")
        #expect(frames.count == 12)
        let bars = frames.map { Int($0[1]) ?? -1 }
        let slides = frames.map { Int($0[2]) ?? -1 }
        #expect(frames.map { $0[0] } == (0..<12).map { "\($0)" })
        // SwiftUI starts its animation a fixed moment after the change; from then on the bar grows 20 pixels a frame.
        let steps = zip(bars, bars.dropFirst()).filter { $0.0 > 0 && $0.1 < 200 }.map { $0.1 - $0.0 }
        #expect(steps.count >= 6, "the bar's widths: \(bars)")
        #expect(steps.allSatisfy { abs($0 - 20) <= 1 }, "the bar's widths: \(bars)")
        // Core Animation's begins with the frame of the change: 18 pixels a frame, to the end at 180.
        #expect(slides.indices.allSatisfy { abs(slides[$0] - min(180, 18 * $0)) <= 1 }, "the square's starts: \(slides)")
        // The process's own clock stands a tenth of a second on at each frame, to the microsecond.
        #expect(frames.map { Int($0[3]) ?? -1 } == (0..<12).map { $0 * 100_000 })
        #expect(found["position"] == ["12"])
    }

    @Test func `the wall time a frame takes changes nothing: a run that waits 60 ms a frame and one that waits 400 ms draw the same pictures`() {
        let (first, second) = (Fixture.run(["live", "60", "6"], inserting: true), Fixture.run(["live", "400", "6"], inserting: true))
        let (quick, slow) = (Self.frames(first), Self.frames(second))
        #expect(first["error"] == nil && second["error"] == nil, "\(first["error"] ?? []) \(second["error"] ?? [])")
        #expect(quick.count == 6)
        #expect(quick == slow)
    }

    @Test func `the same run draws the same pictures every time, an animation begun by a change included`() {
        let runs = (0..<8).map { _ in Self.frames(Fixture.run(["live", "40", "4"], inserting: true)) }
        #expect(runs[0].count == 4)
        #expect(runs.allSatisfy { $0 == runs[0] }, "\(runs.map { $0.map { $0[1] } })")
    }

    @Test func `without the shim library in the process the host refuses to start, and a closed host draws nothing`() {
        let absent = Fixture.run(["live", "60", "1"], inserting: false)["error"] ?? []
        #expect(absent.count == 1 && absent.allSatisfy { $0.hasPrefix("clock(") && $0.hasSuffix("Error.absent)") }, "\(absent)")
        #expect(Fixture.run(["live", "60", "1"], inserting: true)["closed"] == ["closed"])
    }

    @Test func `a size that is not whole points, too narrow or beyond the window server is refused before anything is shown`() async {
        let scale = Int(NSScreen.main?.backingScaleFactor ?? 1)
        let narrow = Cardinal(UInt(14 * scale))
        await #expect(throws: Motion.Hosting.Live.Error.size(width: narrow, height: 40)) {
            _ = try await Motion.Hosting.Live(Color.white, width: narrow, height: 40, rate: .thirty)
        }
        await #expect(throws: Motion.Hosting.Live.Error.size(width: .max, height: 40)) {
            _ = try await Motion.Hosting.Live(Color.white, width: .max, height: 40, rate: .thirty)
        }
        if scale > 1 {
            await #expect(throws: Motion.Hosting.Live.Error.size(width: 201, height: 40)) {
                _ = try await Motion.Hosting.Live(Color.white, width: 201, height: 40, rate: .thirty)
            }
        }
    }
}
