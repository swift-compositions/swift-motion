import CoreGraphics
import Dispatch
import Motion
import Testing

@testable import Motion_Window

/// The hosts' waits: none of these needs the screen.
@MainActor @Suite(.serialized, .timeLimit(.minutes(1)))
struct `Wait Tests` {
    @Test func `a pause of no time returns in the same turn, before anything else on the main queue runs`() async {
        var ran = false
        DispatchQueue.main.async { ran = true }
        await Motion.Hosting.Live.pause(.zero)
        #expect(!ran)
    }

    @Test func `a pause ends when its task is cancelled`() async {
        let clock = ContinuousClock()
        let start = clock.now
        let waiting = Task { @MainActor in await Motion.Hosting.Live.pause(.seconds(20)) }
        waiting.cancel()
        await waiting.value
        #expect(clock.now - start < .seconds(5))
    }

    @Test func `a pause that has begun ends when its task is cancelled`() async {
        let clock = ContinuousClock()
        let start = clock.now
        let waiting = Task { @MainActor in await Motion.Hosting.Live.pause(.seconds(20)) }
        await Motion.Hosting.Live.pause(.milliseconds(100))
        waiting.cancel()
        await waiting.value
        #expect(clock.now - start < .seconds(5))
    }

    @Test func `a pause lasts its time on the wall clock`() async {
        let clock = ContinuousClock()
        let start = clock.now
        await Motion.Hosting.Live.pause(.milliseconds(150))
        let waited = clock.now - start
        #expect(waited >= .milliseconds(140) && waited < .seconds(1))
    }

    @Test func `an answer that comes within the limit is given, and the wait ends with it, not with the limit`() async {
        let clock = ContinuousClock()
        let start = clock.now
        let answer = await Motion.Hosting.Wait.answer(within: .seconds(20)) { 7 }
        #expect(answer == 7)
        #expect(clock.now - start < .seconds(5))
    }

    @Test func `an answer that does not come within the limit is nil at the limit, and an answer of nil is nil at once`() async {
        let clock = ContinuousClock()
        let start = clock.now
        let late = await Motion.Hosting.Wait.answer(within: .milliseconds(150)) { () async -> Int? in
            await Motion.Hosting.Live.pause(.seconds(20))
            return 7
        }
        let waited = clock.now - start
        #expect(late == nil)
        #expect(waited >= .milliseconds(140) && waited < .seconds(1))
        let again = clock.now
        let none = await Motion.Hosting.Wait.answer(within: .seconds(20)) { () async -> Int? in nil }
        #expect(none == nil)
        #expect(clock.now - again < .seconds(5))
    }

    @Test func `a wait for an answer ends when its task is cancelled`() async {
        let clock = ContinuousClock()
        let start = clock.now
        let waiting = Task { @MainActor in
            await Motion.Hosting.Wait.answer(within: .seconds(20)) { () async -> Int? in
                await Motion.Hosting.Live.pause(.seconds(20))
                return 7
            }
        }
        waiting.cancel()
        #expect(await waiting.value == nil)
        #expect(clock.now - start < .seconds(5))
    }

    @Test func `a capture that throws ends the frame there, with what it threw, and no further capture is taken`() async {
        var shots = 0
        await #expect(throws: Motion.Hosting.Live.Error.capture(frame: 3, "late")) {
            _ = try await Motion.Hosting.Live.settled(3, number: 7, width: 64, height: 8, scale: 2, between: .zero) { () async throws(Motion.Hosting.Live.Error) -> CGImage? in
                shots += 1
                throw .capture(frame: 3, "late")
            } reason: {
                "none"
            }
        }
        #expect(shots == 1)
    }
}
