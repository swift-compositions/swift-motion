import AppKit
import Motion
import Motion_Window
import Observation
import QuartzCore
import SwiftUI

extension Fixture {
    @MainActor @Observable final class Model {
        var started = false
    }

    /// Two animations of one second each, both linear: on top a black bar SwiftUI grows from nothing to the
    /// full 200 pixels, below it a black square Core Animation slides from the left edge to 180 pixels.
    struct Stage: View {
        let model: Model
    }

    struct Slide: NSViewRepresentable {
        let started: Bool
    }
}

extension Fixture.Stage {
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Color.white
                Color.black.frame(width: model.started ? 200 : 0).animation(.linear(duration: 1), value: model.started)
            }
            .frame(width: 200, height: 20)
            Fixture.Slide(started: model.started).frame(width: 200, height: 20)
        }
    }
}

extension Fixture.Slide {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        let square = CALayer()
        square.backgroundColor = NSColor.black.cgColor
        square.anchorPoint = .zero
        square.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        view.layer?.addSublayer(square)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard started, let square = view.layer?.sublayers?.first, square.animation(forKey: "slide") == nil else { return }
        let slide = CABasicAnimation(keyPath: "position.x")
        slide.fromValue = 0
        slide.toValue = 180
        slide.duration = 1
        slide.timingFunction = CAMediaTimingFunction(name: .linear)
        slide.fillMode = .both
        slide.isRemovedOnCompletion = false
        square.add(slide, forKey: "slide")
    }
}

extension Fixture {
    /// Steps the stage at ten frames a second and prints, for each frame, how many pixels of the bar's row
    /// are dark, where the square's row first turns dark, the microseconds of uptime since frame zero as the
    /// process reads it, and a digest of the picture.
    @MainActor static func live(settle: Duration, frames: Cardinal) async {
        let model = Model()
        do throws(Motion.Hosting.Live.Error) {
            let tenth = try rate()
            let live = try await Motion.Hosting.Live(Stage(model: model), width: 200, height: 40, rate: tenth, warm: .milliseconds(300), settle: settle)
            var frame = Ordinal.zero
            var first: Double?
            while frame < Ordinal(frames) {
                var uptime = 0.0
                let raster = try await live.frame { _ in
                    model.started = true
                    uptime = CACurrentMediaTime()
                }
                first = first ?? uptime
                let bar = raster.row(10).count { $0.red < 128 }
                let slide = raster.row(30).firstIndex { $0.red < 128 }.map { $0 - raster.row(30).startIndex } ?? -1
                let since = Int(((uptime - (first ?? uptime)) * 1_000_000).rounded())
                let digest = raster.bytes.reduce(14_695_981_039_346_656_037 as UInt64) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
                line("frame", "\(frame) \(bar) \(slide) \(since) \(digest)")
                frame += Cardinal.one
            }
            line("position", live.position)
            live.close()
            do throws(Motion.Hosting.Live.Error) {
                _ = try await live.frame()
                line("closed", "drew")
            } catch {
                line("closed", error)
            }
        } catch {
            line("error", error)
        }
    }

    static func rate() throws(Motion.Hosting.Live.Error) -> Rate {
        do throws(Rate.Error) {
            return try Rate(10)
        } catch {
            throw .window("ten a second is a rate")
        }
    }
}
