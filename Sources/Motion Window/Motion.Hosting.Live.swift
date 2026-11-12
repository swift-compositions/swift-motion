import AppKit
import Dispatch
public import Motion
import Motion_Cache
import Motion_Clock
import ScreenCaptureKit
public import SwiftUI

extension Motion.Hosting {
    /// Hosts one live view for a whole run of frames and steps its time, so the view's own animations
    /// advance by exactly one frame per frame and never with the wall clock.
    ///
    /// Where `Window` gives each frame a fresh view, `Live` keeps one: state, running animations and
    /// effects carry over, as in the app the view comes from. The view first runs on the machine's clock
    /// for a warm-up, so what it does on appearing is over. Then the process's clock is frozen through
    /// `Motion.Clock` and the host's layer time is stopped. Each `frame` moves both one frame on, applies
    /// the caller's change and draws it in the same turn, gives the run loop some wall time, and captures
    /// the window until a capture shows this frame's fence and the next capture is the same picture.
    ///
    /// It needs Screen Recording permission, one capturing process at a time, and the `Motion Clock Shims`
    /// library in the process from launch.
    @MainActor public final class Live {
        let window: Motion.Hosting.Window.Sealed
        let filter: SCContentFilter
        let fence: Fence
        let clock: Motion.Clock
        let origin: Duration
        let width: Int
        let height: Int
        let scale: Int
        let settle: Duration

        /// The rate frames are stepped at.
        public let rate: Rate

        /// The frame the next call to `frame` draws.
        public private(set) var position: Ordinal

        var closed = false

        /// Shows `view` at `width` by `height` pixels, lets it run for `warm` on the machine's clock, then
        /// freezes time at the start of frame zero. `settle` is the wall time each frame is given to draw
        /// before it is captured.
        public init(
            _ view: some SwiftUI.View,
            width: Cardinal,
            height: Cardinal,
            rate: Rate,
            warm: Duration = .milliseconds(800),
            settle: Duration = .milliseconds(120)
        ) async throws(Error) {
            let scale = Motion.Hosting.Window.scale
            guard let wide = Int(exactly: width), let tall = Int(exactly: height), wide <= Int(Int32.max), tall <= Int(Int32.max),
                wide % scale == 0, tall % scale == 0, wide >= 16 * scale
            else { throw .size(width: width, height: height) }
            let fence = Fence()
            let size = NSSize(width: wide / scale, height: tall / scale + 1)
            _ = NSApplication.shared
            let window = Motion.Hosting.Window.Sealed(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .aqua)
            window.colorSpace = .sRGB
            window.hasShadow = false
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
            let host = NSHostingView(
                rootView: VStack(spacing: 0) {
                    view.frame(width: Double(wide), height: Double(tall))
                    Fence.Band(fence: fence, cell: Double(wide) / 16, height: Double(scale))
                }
                .allowsHitTesting(false)
                .scaleEffect(1 / Double(scale), anchor: .topLeading)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
            )
            window.contentView = host
            window.orderFrontRegardless()
            await Self.pause(max(warm, .milliseconds(200)))
            let limit = Motion.Hosting.Window.limit
            let asked = await Motion.Hosting.Wait.answer(within: limit) { () async -> Result<SCShareableContent, any Swift.Error>? in
                // swift-linter:disable:next do throws for typed catch
                // REASON: SCShareableContent throws untyped; its error becomes Error.window.
                do {
                    return .success(try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false))
                } catch {
                    return .failure(error)
                }
            }
            let content: SCShareableContent
            switch asked {
            case .success(let found):
                content = found
            case .failure(let error):
                window.close()
                throw .window("\(error)")
            case nil:
                window.close()
                throw .window("the window server did not say what can be captured within \(limit)")
            }
            guard let shared = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
                window.close()
                throw .window("it is not among the windows that can be captured")
            }
            let clock: Motion.Clock
            do throws(Motion.Clock.Error) {
                clock = try Motion.Clock()
            } catch {
                window.close()
                throw .clock(error)
            }
            host.wantsLayer = true
            host.layer?.speed = 0
            host.layer?.timeOffset = 0
            CATransaction.flush()
            self.window = window
            self.filter = SCContentFilter(desktopIndependentWindow: shared)
            self.fence = fence
            self.clock = clock
            self.origin = clock.elapsed
            self.width = wide
            self.height = tall
            self.scale = scale
            self.settle = settle
            self.rate = rate
            self.position = .zero
        }
    }
}

extension Motion.Hosting.Live {
    /// Moves time on by one frame and draws the frame at `position`.
    ///
    /// Time moves first: the process's clock and the host's layer time both go one frame's duration on,
    /// to the exact start of the frame after `position` counted from the freeze. In the same turn, before
    /// the run loop can draw anything at the new time, `change` runs with the frame's position (it is
    /// where the caller changes what the view shows for this frame) and the host lays the view out and
    /// draws it. A change drawn later than the first draw at its time would have its animations begin a
    /// frame late, now and then; and under a frozen clock an update SwiftUI puts off waits on a run-loop
    /// timer that does not fire until the clock has passed it. Then the run loop gets `settle` of wall
    /// time, in which what the change set off elsewhere (a task, a stream, an effect) reaches the view,
    /// and the host draws once more, so that this frame shows it and not the next. The picture returned
    /// is a capture that showed this frame's fence and was followed by an identical capture. `position`
    /// goes up only when a picture is returned.
    public func frame(_ change: (Ordinal) -> Void = { _ in }) async throws(Error) -> Raster<Motion.Pixel> {
        guard !closed else { throw .closed }
        await Motion.Hosting.Window.turn()
        defer { Motion.Hosting.Window.done() }
        let frame = position
        let next = frame + Cardinal.one
        do throws(Motion.Clock.Error) {
            try clock.advance(to: origin + Motion.Clock.start(of: next, at: rate))
        } catch {
            throw .clock(error)
        }
        window.contentView?.layer?.timeOffset = rate.start(of: Integer(Int(clamping: Cardinal(next)))).approximation(as: Double.self)
        Motion.Hosting.Window.count += 1
        let number = Motion.Hosting.Window.count
        change(frame)
        fence.number = number
        draw()
        await Self.pause(settle)
        draw()
        let picture = try await capture(frame, number: number)
        position = next
        return picture
    }

    /// Lays the view out and draws it now, whatever SwiftUI has put off.
    func draw() {
        window.contentView?.needsLayout = true
        window.contentView?.layoutSubtreeIfNeeded()
        window.contentView?.display()
        CATransaction.flush()
    }

    /// Closes the window. The process's clock stays frozen where it stands.
    public func close() {
        closed = true
        window.close()
    }
}

extension Motion.Hosting.Live {
    /// Waits `duration` of wall time on the main queue. A sleep measured on the machine's uptime would be
    /// measured on the frozen clock, so this one is set against the wall clock. No time at all is no
    /// wait: it returns in the same turn. A cancelled task's pause ends at once.
    static func pause(_ duration: Duration) async {
        guard duration > .zero else { return }
        _ = await Motion.Hosting.Wait<Never>.answer(within: duration)
    }

    /// A capture of the window that shows capture `number` and is followed by an identical capture.
    func capture(_ frame: Ordinal, number: Int) async throws(Error) -> Raster<Motion.Pixel> {
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height + scale
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        unsafe config.colorSpaceName = CGColorSpace.sRGB
        var refused = "it never showed its fence"
        let (filter, limit) = (filter, Motion.Hosting.Window.limit)
        return try await Self.settled(frame, number: number, width: width, height: height, scale: scale, between: .milliseconds(50)) { () async throws(Error) -> CGImage? in
            let asked = await Motion.Hosting.Wait.answer(within: limit) { () async -> Result<CGImage, any Swift.Error>? in
                // swift-linter:disable:next do throws for typed catch
                // REASON: SCScreenshotManager.captureImage throws untyped; a capture that fails counts as none and its error is the reason given.
                do {
                    return .success(try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config))
                } catch {
                    return .failure(error)
                }
            }
            switch asked {
            case .success(let image):
                return image
            case .failure(let error):
                refused = "\(error)"
                return nil
            case nil:
                throw .capture(frame: frame, "a capture did not return within \(limit)")
            }
        } reason: {
            refused
        }
    }

    /// Takes captures with `shot`, up to forty pairs, until one shows `number` in its band and the capture
    /// after it is the same picture, band included; gives that picture without its band. Fails with
    /// `.unsettled` when captures showed the number but no two in a row agreed, and with `.capture` and
    /// `reason` when none showed it. A `shot` that throws ends the frame there, with what it threw.
    static func settled(
        _ frame: Ordinal,
        number: Int,
        width: Int,
        height: Int,
        scale: Int,
        between: Duration,
        shot: () async throws(Error) -> CGImage?,
        reason: () -> String
    ) async throws(Error) -> Raster<Motion.Pixel> {
        var fenced = false
        var attempt = 0
        while attempt < 40 {
            attempt += 1
            if let first = try await shot(), shows(first, number: number, width: width, height: height, scale: scale) {
                fenced = true
                if let second = try await shot(), bytes(first) == bytes(second),
                    let raster = Raster<Motion.Pixel>(image: first), let picture = Motion.Hosting.Window.picture(raster, rows: Cardinal(UInt(height)))
                {
                    return picture
                }
            }
            await pause(between)
        }
        throw fenced ? .unsettled(frame: frame) : .capture(frame: frame, reason())
    }

    static func bytes(_ image: CGImage) -> CFData? { image.dataProvider?.data }

    /// Whether `image` is a capture of a `width` by `height` picture whose band below it spells `number`.
    static func shows(_ image: CGImage, number: Int, width: Int, height: Int, scale: Int) -> Bool {
        guard image.bitsPerPixel == 32, image.width == width, image.height == height + scale, let data = Self.bytes(image) else { return false }
        let row = (height + scale / 2) * image.bytesPerRow
        let cell = Double(width) / 16
        let digits = Motion.Hosting.Window.digits(number)
        guard CFDataGetLength(data) >= row + width * 4, let base = unsafe CFDataGetBytePtr(data) else { return false }
        return (0..<16).allSatisfy { index in
            let probe = row + Int((Double(index) + 0.5) * cell) * 4
            return unsafe Motion.Hosting.Window.digit(red: base[probe + 2], green: base[probe + 1], blue: base[probe]) == digits[index]
        }
    }
}
