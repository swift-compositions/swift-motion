public import AppKit
public import Motion
public import SwiftUI

extension Hosting {
    /// Draws a view on the CPU with `cacheDisplay`, in an off-screen window, with a fresh hosting
    /// view each frame so no state or animation carries over from the previous one.
    ///
    /// It needs no permission, so it serves machines without Screen Recording access. Its blur
    /// and shadows are CoreGraphics' software versions, a little different from the screen's.
    @MainActor public enum Cache {
    }
}

extension Hosting.Cache {
    static var window: NSWindow?
}

extension Hosting.Cache {
    /// Closes the window, so the next frame starts from a new one.
    public static func forget() {
        window?.close()
        window = nil
    }

    static func ready(width: Int, height: Int) -> NSWindow {
        let size = NSSize(width: width, height: height)
        if let window, window.frame.size == size { return window }
        forget()
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -100_000, y: -100_000), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.orderFrontRegardless()
        self.window = window
        return window
    }

    /// The view drawn at `width` by `height` points, one pixel per point.
    public static func image(_ view: some SwiftUI.View, width: Int, height: Int) -> CGImage? {
        autoreleasepool {
            let window = ready(width: width, height: height)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
            window.contentView = host
            defer { window.contentView = nil }
            host.layoutSubtreeIfNeeded()
            guard
                let bitmap = unsafe NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: width,
                    pixelsHigh: height,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                )
            else { return nil }
            bitmap.size = NSSize(width: width, height: height)
            host.cacheDisplay(in: host.bounds, to: bitmap)
            return bitmap.retagging(with: .sRGB)?.cgImage
        }
    }

    public static func raster(_ view: some SwiftUI.View, width: Int, height: Int) -> Raster<Frame.Pixel>? {
        image(view, width: width, height: height).flatMap(Raster<Frame.Pixel>.init(image:))
    }
}
