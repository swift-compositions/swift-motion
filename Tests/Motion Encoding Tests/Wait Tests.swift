import AVFoundation
import Dispatch
import Foundation
import Motion
import Test_Apple
import Testing

@testable import Motion_Encoding

extension `Encoding Tests` {
    /// The waits on AVFoundation, each with its limit on the wall clock.
    @Suite(.deadline(.seconds(180))) struct `Wait Tests` {
        /// Blocks the calling thread until the semaphore is signalled, as a reader's next sample does.
        static func block(_ semaphore: DispatchSemaphore) {
            semaphore.wait()
        }

        /// Whether the semaphore is signalled within some seconds.
        static func signalled(_ semaphore: DispatchSemaphore, within seconds: Double) -> Bool {
            semaphore.wait(timeout: .now() + seconds) == .success
        }

        /// Whether a failure is a wait past its limit.
        static func unanswered(_ failure: Motion.Encoding.Error) -> Bool {
            if case .unanswered = failure { return true }
            return false
        }

        @Test func `an answer within the limit is given, and the wait ends with it, not with the limit`() async throws {
            let clock = ContinuousClock()
            let start = clock.now
            let answer = try await Motion.Encoding.Wait.answer("seven") { 7 }
            #expect(answer == 7)
            #expect(clock.now - start < .seconds(5))
        }

        @Test func `a call that blocks its thread past the limit fails at the limit, naming what was waited for, and is left behind`() async throws {
            let held = DispatchSemaphore(value: 0)
            let stopped = DispatchSemaphore(value: 0)
            let clock = ContinuousClock()
            let start = clock.now
            await #expect(throws: Motion.Encoding.Error.unanswered("a sample did not come within 0.15 seconds")) {
                try await Motion.Encoding.Wait.$limit.withValue(.milliseconds(150)) {
                    try await Motion.Encoding.Wait.answer("a sample", stop: { stopped.signal() }) {
                        Self.block(held)
                        return 7
                    }
                }
            }
            let waited = clock.now - start
            #expect(waited >= .milliseconds(140) && waited < .seconds(2))
            #expect(Self.signalled(stopped, within: 1))
            held.signal()
        }

        @Test func `a limit of no time fails at once and starts nothing`() async {
            let started = DispatchSemaphore(value: 0)
            await #expect(throws: Motion.Encoding.Error.unanswered("a load did not come within 0.0 seconds")) {
                try await Motion.Encoding.Wait.$limit.withValue(.zero) {
                    try await Motion.Encoding.Wait.answer("a load") { started.signal() }
                }
            }
            #expect(!Self.signalled(started, within: 0.2))
        }

        @Test func `every read, inspection, score, reduction and write fails with unanswered when its waits have no time`() async throws {
            let movie = try await `Encoding Tests`.written(rate: .thirty)
            let sound = try `Encoding Tests`.`Score Tests`.tone(seconds: 1)
            let output = { FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4") }
            let clock = ContinuousClock()
            let start = clock.now
            await Motion.Encoding.Wait.$limit.withValue(.zero) {
                do throws(Motion.Encoding.Error) {
                    _ = try await Motion.Encoding.Inspection(of: movie)
                    Issue.record("an inspection read without waiting")
                } catch {
                    #expect(Self.unanswered(error), "\(error)")
                }
                do throws(Motion.Encoding.Error) {
                    _ = try await Motion.Encoding.read(movie) { _, _ in }
                    Issue.record("a read read without waiting")
                } catch {
                    #expect(Self.unanswered(error), "\(error)")
                }
                do throws(Motion.Encoding.Error) {
                    _ = try await Motion.Decoding(movie)
                    Issue.record("a decoding read without waiting")
                } catch {
                    #expect(Self.unanswered(error), "\(error)")
                }
                do throws(Motion.Encoding.Error) {
                    try await Motion.Encoding.score(movie, with: [Motion.Encoding.Cue(sound)], to: output())
                    Issue.record("a score was laid without waiting")
                } catch {
                    #expect(Self.unanswered(error), "\(error)")
                }
                do throws(Motion.Encoding.Error) {
                    try await Motion.Encoding.reduced(movie, to: output(), as: .height540)
                    Issue.record("a movie was reduced without waiting")
                } catch {
                    #expect(Self.unanswered(error), "\(error)")
                }
                #if File
                    do throws(Motion.Encoding.Error) {
                        try await Motion.Encoding.reduced(movie, to: output(), within: 1000)
                        Issue.record("a movie was reduced to a limit without waiting")
                    } catch {
                        #expect(Self.unanswered(error), "\(error)")
                    }
                #endif
                do throws(Motion.Encoding.Error) {
                    try await Motion.Encoding.mux(movie, sound, to: output())
                    Issue.record("a movie was joined without waiting")
                } catch {
                    #expect(Self.unanswered(error), "\(error)")
                }
                do throws(Motion.Encoding.Error) {
                    try await Motion.Encoding(width: 320, height: 180, rate: .thirty).write(frames: 2, to: output()) { `Encoding Tests`.gradient($0) }
                    Issue.record("a movie was written without waiting")
                } catch {
                    #expect(Self.unanswered(error), "\(error)")
                }
            }
            #expect(clock.now - start < .seconds(5))
        }

        @Test func `a decoding made in time fails with unanswered when its frames have no time`() async throws {
            let movie = try await Motion.Decoding(try await `Encoding Tests`.written(rate: .thirty))
            await Motion.Encoding.Wait.$limit.withValue(.zero) {
                do throws(Motion.Encoding.Error) {
                    _ = try await movie.frames(positions: [0])
                    Issue.record("a frame was decoded without waiting")
                } catch {
                    #expect(Self.unanswered(error), "\(error)")
                }
            }
            #expect(try await movie.frames(positions: [0]).count == 1)
        }
    }
}
