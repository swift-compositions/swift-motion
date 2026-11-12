import AppKit
public import Motion
import Motion_Cache
import ScreenCaptureKit
public import SwiftUI

extension Motion.Hosting {
    /// Draws a view the way the screen does, on the GPU through the window server, and captures it
    /// with ScreenCaptureKit.
    ///
    /// A borderless window one level below the desktop holds a fresh hosting view each frame, so
    /// it is never seen and no state carries over. Its layer clock is frozen, so live animations
    /// such as a spinning progress view cannot tick between frames. Below the picture a one-point
    /// fence band of sixteen cells, each black, red, green or blue, spells the capture's own number
    /// in base 4; a capture counts only when it shows exactly that number, so no other frame is
    /// ever taken for this one. Captures take turns: one that starts while another is drawing
    /// waits for it, and `forget()` takes effect once the capture in progress is done. The window measures whole points and is captured at its own
    /// pixel size, so the picture is never resampled. Hit testing is off, and the window drops
    /// pointer events and reports the pointer far away, so a pointer in that corner of the screen
    /// can hardly hover a view in the picture.
    ///
    /// It needs Screen Recording permission, and one process at a time: with several processes
    /// capturing at once, ScreenCaptureKit's calls stop returning.
    @MainActor public enum Window {
    }
}

extension Motion.Hosting.Window {
    static var window: NSWindow?

    static var filter: SCContentFilter?

    static var count = 0

    static var drawing = false

    static var waiting: [CheckedContinuation<Void, Never>] = []

    static var forgetting = false

    static var opened = 0

    /// How long the hosts wait for one answer from ScreenCaptureKit before the frame fails. A capture
    /// takes milliseconds; one that has not come back by now is not coming.
    static var limit: Duration = .seconds(10)
}

extension Motion.Hosting.Window {
    /// Closes the window, so the next frame starts from a new one; during a capture, once it is done.
    public static func forget() {
        guard !drawing else {
            forgetting = true
            return
        }
        close()
    }

    static func close() {
        window?.close()
        window = nil
        filter = nil
    }

    static func turn() async {
        guard drawing else {
            drawing = true
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    static func done() {
        drawing = false
        if forgetting {
            forgetting = false
            close()
        }
        guard !waiting.isEmpty else { return }
        drawing = true
        waiting.removeFirst().resume()
    }

    /// The fence's sixteen base-4 digits for capture `number`, least significant first.
    static func digits(_ number: Int) -> [Int] { (0..<16).map { number >> (2 * $0) & 3 } }

    /// The digit a fence cell shows: black 0, red 1, green 2, blue 3, or nil for anything else.
    static func digit(red: UInt8, green: UInt8, blue: UInt8) -> Int? {
        switch (red > 200, green > 200, blue > 200, red < 50, green < 50, blue < 50) {
        case (false, false, false, true, true, true): 0
        case (true, false, false, false, true, true): 1
        case (false, true, false, true, false, true): 2
        case (false, false, true, true, true, false): 3
        default: nil
        }
    }

    static func colour(_ digit: Int) -> Color {
        Color(.sRGB, red: digit == 1 ? 1 : 0, green: digit == 2 ? 1 : 0, blue: digit == 3 ? 1 : 0)
    }

    /// Pixels per point on the main screen.
    static var scale: Int { Int(NSScreen.main?.backingScaleFactor ?? 1) }

    static func ready(width: Int, height: Int) async -> (NSWindow, SCContentFilter)? {
        let size = NSSize(width: width / scale, height: height / scale + 1)
        if let window, let filter, window.frame.size == size { return (window, filter) }
        close()
        _ = NSApplication.shared
        let window = Sealed(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        opened += 1
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.colorSpace = .sRGB
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.orderFrontRegardless()
        // swift-linter:disable:next try optional
        // REASON: Task.sleep throws only on cancellation, and a cancelled render fails at its next capture.
        try? await Task.sleep(for: .milliseconds(200))
        let asked = await Motion.Hosting.Wait.answer(within: limit) { () async -> SCShareableContent? in
            // swift-linter:disable:next try optional
            // REASON: SCShareableContent throws untyped; without the window's content the frame fails as nil.
            try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        }
        guard let content = asked, let shared = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
            window.close()
            return nil
        }
        let filter = SCContentFilter(desktopIndependentWindow: shared)
        self.window = window
        self.filter = filter
        return (window, filter)
    }

    /// The view drawn at `width` by `height` pixels, or nil when it cannot be captured.
    ///
    /// Both sizes must be whole points on the main screen: even numbers on a Retina display. A size
    /// beyond 32 bits, more than the window server can be told, is nil too.
    public static func raster(_ view: some SwiftUI.View, width: Cardinal, height: Cardinal) async -> Raster<Motion.Pixel>? {
        guard let width = Int(exactly: width), let height = Int(exactly: height), width <= Int(Int32.max), height <= Int(Int32.max) else { return nil }
        let scale = scale
        guard width % scale == 0, height % scale == 0, width >= 16 * scale else { return nil }
        await turn()
        defer { done() }
        guard let (window, filter) = await ready(width: width, height: height) else { return nil }
        count += 1
        let fence = digits(count)
        let cell = Double(width) / 16
        let host = NSHostingView(
            rootView: VStack(spacing: 0) {
                view.frame(width: Double(width), height: Double(height))
                HStack(spacing: 0) {
                    ForEach(0..<16, id: \.self) { index in colour(fence[index]).frame(width: cell, height: Double(scale)) }
                }
                .frame(width: Double(width), height: Double(scale))
            }
            .allowsHitTesting(false)
            .scaleEffect(1 / Double(scale), anchor: .topLeading)
            .frame(width: Double(width / scale), height: Double(height / scale + 1), alignment: .topLeading)
        )
        window.contentView = host
        host.wantsLayer = true
        host.layer?.speed = 0
        host.layoutSubtreeIfNeeded()
        host.display()
        CATransaction.flush()
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height + scale
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        unsafe config.colorSpaceName = CGColorSpace.sRGB
        for _ in 0..<400 {
            let asked = await Motion.Hosting.Wait.answer(within: limit) { () async -> CGImage? in
                // swift-linter:disable:next try optional
                // REASON: captureImage throws untyped; a frame that cannot be captured fails as nil.
                try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            }
            guard let image = asked, let fenced = Raster<Motion.Pixel>(image: image) else { return nil }
            let bytes = fenced.bytes
            let row = (height + scale / 2) * width
            let shown = (0..<16).map { index -> Int? in
                let probe = (row + Int((Double(index) + 0.5) * cell)) * 4
                return digit(red: bytes[probe + 2], green: bytes[probe + 1], blue: bytes[probe])
            }
            if shown == fence.map(Optional.some) {
                return Self.picture(fenced, rows: Cardinal(UInt(height)))
            }
            // swift-linter:disable:next try optional
            // REASON: Task.sleep throws only on cancellation; the next capture then fails.
            try? await Task.sleep(for: .milliseconds(2))
        }
        return nil
    }
}

extension Motion.Hosting.Window {
    /// The top `rows` rows of a capture: the picture without the fence band below it.
    static func picture(_ fenced: Raster<Motion.Pixel>, rows: Cardinal) -> Raster<Motion.Pixel>? {
        do throws(Raster<Motion.Pixel>.Error) {
            return try fenced.cropped(to: .init(x: 0, y: 0, width: fenced.width, height: rows))
        } catch {
            return nil
        }
    }
}
