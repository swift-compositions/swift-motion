import AppKit
import ApplicationServices
import CoreGraphics
import Motion
import Motion_Window
import SwiftUI
import Testing

/// Moves the real pointer over the capture window's corner of the screen, so it runs only where
/// this process may post events, and puts the pointer back.
@MainActor
@Suite(
    .enabled(if: CGPreflightScreenCaptureAccess() && AXIsProcessTrusted(), "needs Screen Recording and Accessibility"),
    .serialized
)
struct `Pointer Tests` {
    @Test func `a pointer moving over the window's corner of the screen hovers nothing in the picture`() async throws {
        let original = NSEvent.mouseLocation
        let height = try #require(NSScreen.main?.frame.height)
        defer { CGWarpMouseCursorPosition(CGPoint(x: original.x, y: height - original.y)) }
        for step in 0..<4 {
            let point = CGPoint(x: 40 + step * 10, y: Int(height) - 40 - step * 10)
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(60))
            let raster = try #require(await Hosting.Window.raster(Hovering(), width: 320, height: 180))
            #expect(raster.bytes[0] == 255, "step \(step): the pointer hovered the view")
        }
    }
}
