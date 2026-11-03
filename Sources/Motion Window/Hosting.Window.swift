import AppKit
public import Motion
import Motion_Cache
import ScreenCaptureKit
public import SwiftUI

extension Hosting {
    /// Draws a view the way the screen does, on the GPU through the window server, and captures it
    /// with ScreenCaptureKit.
    ///
    /// A borderless window one level below the desktop holds a fresh hosting view each frame, so
    /// it is never seen and no state carries over. Its layer clock is frozen, so live animations
    /// such as a spinning progress view cannot tick between frames. Below the picture a one-point
    /// fence band in pure red, green or blue encodes the frame number modulo 3; a capture counts
    /// only when it shows this frame's fence, so a frame the window server has not yet drawn is
    /// never taken for this one. The window measures whole points and is captured at its own
    /// pixel size, so the picture is never resampled.
    ///
    /// It needs Screen Recording permission, and one process at a time: with several processes
    /// capturing at once, ScreenCaptureKit's calls stop returning.
    @MainActor public enum Window {
        static var window: NSWindow?
        static var filter: SCContentFilter?
        static var count = 0
    }
}

extension Hosting.Window {
    /// Closes the window, so the next frame starts from a new one.
    public static func forget() {
        window?.close()
        window = nil
        filter = nil
    }

    /// Pixels per point on the main screen.
    static var scale: Int { Int(NSScreen.main?.backingScaleFactor ?? 1) }

    static func ready(width: Int, height: Int) async -> (NSWindow, SCContentFilter)? {
        let size = NSSize(width: width / scale, height: height / scale + 1)
        if let window, let filter, window.frame.size == size { return (window, filter) }
        forget()
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.colorSpace = .sRGB
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.orderFrontRegardless()
        // swift-linter:disable:next try optional
        // REASON: Task.sleep throws only on cancellation, and a cancelled render fails at its next capture.
        try? await Task.sleep(for: .milliseconds(200))
        // swift-linter:disable:next try optional
        // REASON: SCShareableContent throws untyped; without the window's content the frame fails as nil.
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
            let shared = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) })
        else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: shared)
        self.window = window
        self.filter = filter
        return (window, filter)
    }

    /// The view drawn at `width` by `height` pixels, or nil when it cannot be captured.
    ///
    /// Both sizes must be whole points on the main screen: even numbers on a Retina display.
    public static func raster(_ view: some SwiftUI.View, width: Int, height: Int) async -> Raster? {
        let scale = scale
        guard width % scale == 0, height % scale == 0, let (window, filter) = await ready(width: width, height: height) else { return nil }
        count += 1
        let fence = count % 3
        let host = NSHostingView(
            rootView: VStack(spacing: 0) {
                view.frame(width: Double(width), height: Double(height))
                Color(.sRGB, red: fence == 0 ? 1 : 0, green: fence == 1 ? 1 : 0, blue: fence == 2 ? 1 : 0)
                    .frame(width: Double(width), height: Double(scale))
            }
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
            // swift-linter:disable:next try optional
            // REASON: captureImage throws untyped; a frame that cannot be captured fails as nil.
            guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config),
                let fenced = Raster(image: image)
            else { return nil }
            let probe = ((height + scale / 2) * width + width / 2) * 4
            let channel = [fenced.bytes[probe + 2], fenced.bytes[probe + 1], fenced.bytes[probe]]
            if channel[fence] > 200 && channel.enumerated().allSatisfy({ $0.offset == fence || $0.element < 50 }) {
                return fenced.top(height)
            }
            // swift-linter:disable:next try optional
            // REASON: Task.sleep throws only on cancellation; the next capture then fails.
            try? await Task.sleep(for: .milliseconds(2))
        }
        return nil
    }
}
