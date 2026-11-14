import Foundation
import Motion
import Motion_Clock

extension Fixture {
    /// What woke, in the order it ran, each with where the clock stood when it did.
    @MainActor final class Wakes {
        var lines: [String] = []

        func note(_ name: String, _ clock: Motion.Clock.Stepped) {
            let line = "\(name)@\(clock.now.elapsed.components.seconds * 1000 + clock.now.elapsed.components.attoseconds / 1_000_000_000_000_000)"
            lines.append(line)
            Fixture.line("woke", line)
        }
    }

    /// Waits `milliseconds` of wall time without holding the main actor, so what is due on it runs meanwhile.
    static func wall(milliseconds: UInt32) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Thread.detachNewThread {
                usleep(milliseconds * 1000)
                continuation.resume()
            }
        }
    }

    /// Sleeps on the stepped clock from the main actor until `deadline` milliseconds from the freeze, and
    /// notes the wake or the cancellation. The sleep has begun when this returns.
    @MainActor @discardableResult
    static func nap(_ name: String, until deadline: Int64, on clock: Motion.Clock.Stepped, into wakes: Wakes) -> Task<Void, Never> {
        Task.immediate { @MainActor in
            do throws(CancellationError) {
                try await clock.sleep(until: .init(.milliseconds(deadline)))
                wakes.note(name, clock)
            } catch {
                wakes.note("\(name):cancelled", clock)
            }
        }
    }

    @MainActor static func sleeping() async {
        let stepped: Motion.Clock.Stepped
        do throws(Motion.Clock.Error) {
            stepped = try Motion.Clock.Stepped()
        } catch {
            line("error", error)
            return
        }
        let wakes = Wakes()
        line("unfrozen", stepped.now.elapsed == .zero)
        nap("early", until: 100, on: stepped, into: wakes)
        let clock: Motion.Clock
        do throws(Motion.Clock.Error) {
            clock = try Motion.Clock()
        } catch {
            line("error", error)
            return
        }
        let erased: any Clock<Duration> = stepped
        _ = Task.immediate { @MainActor in
            do {
                try await erased.sleep(for: .milliseconds(300))
                wakes.note("erased", stepped)
            } catch {
                wakes.note("erased:cancelled", stepped)
            }
        }
        nap("second", until: 200, on: stepped, into: wakes)
        nap("tie", until: 200, on: stepped, into: wakes)
        await wall(milliseconds: 400)
        line("unadvanced", wakes.lines.isEmpty)

        func step(_ milliseconds: Int64) async {
            Fixture.attempt("advance") { () throws(Motion.Clock.Error) in try clock.advance(to: .milliseconds(milliseconds)) }
            await wall(milliseconds: 60)
        }
        await step(99)
        line("before", wakes.lines.isEmpty)
        await step(100)
        await step(199)
        await step(200)
        await step(400)
        line("order", wakes.lines.joined(separator: ","))

        wakes.lines = []
        (0..<20).forEach { nap("m\($0)", until: 500, on: stepped, into: wakes) }
        await step(500)
        line("many", wakes.lines == (0..<20).map { "m\($0)@500" })

        wakes.lines = []
        _ = Task.immediate { @MainActor in
            do throws(CancellationError) {
                try await stepped.sleep(for: .zero)
                try await stepped.sleep(until: .init(.milliseconds(10)))
                wakes.lines.append("returned")
            } catch {
                wakes.lines.append("cancelled")
            }
        }
        line("immediate", wakes.lines == ["returned"])

        wakes.lines = []
        let cancelled = nap("cancelled", until: 10_000, on: stepped, into: wakes)
        cancelled.cancel()
        await wall(milliseconds: 60)
        line("cancelled", wakes.lines.joined(separator: ","))
        wakes.lines = []
        _ = Task.immediate { @MainActor in
            unsafe withUnsafeCurrentTask { unsafe $0?.cancel() }
            do throws(CancellationError) {
                try await stepped.sleep(until: .init(.seconds(10)))
            } catch {
                wakes.lines.append("refused")
            }
        }
        line("refused", wakes.lines == ["refused"])
        wakes.lines = []
        await step(20_000)
        line("withdrawn", wakes.lines.isEmpty ? "none" : wakes.lines.joined(separator: ","))
        line("elapsed", clock.elapsed == .seconds(20))
    }
}
