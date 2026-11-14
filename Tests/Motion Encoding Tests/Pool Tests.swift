import AVFoundation
import Dispatch
import Foundation
import Synchronization
import Motion
import Test_Apple
import Testing

@testable import Motion_Encoding

extension `Encoding Tests` {
    /// AVFoundation's own readers stop when every thread of Swift's cooperative pool is busy (measured on macOS
    /// 27.2: a reader's next sample and a writer's receiver never answer then, a load and a writer fed through a
    /// pixel buffer adaptor do), so this package keeps the pool free of its blocking calls and its limits fire
    /// without a thread of the pool, on a machine of any size.
    @Suite(.deadline(.seconds(180))) struct `Pool Tests` {
        /// Blocks the calling thread until the semaphore is signalled.
        static func block(_ semaphore: DispatchSemaphore) {
            semaphore.wait()
        }

        /// How many of `count` signals came within `seconds`, all told.
        static func count(_ signals: DispatchSemaphore, _ count: Int, within seconds: Double) -> Int {
            let deadline = DispatchTime.now() + seconds
            var seen = 0
            while seen < count, signals.wait(timeout: deadline) == .success { seen += 1 }
            return seen
        }

        /// Runs `work` while as many tasks as the machine has active processors, one for each thread of the
        /// cooperative pool, block their threads; the caller waits on a reader's thread, outside the pool. Gives
        /// how many blocked, and whether `work` ended within `seconds`.
        static func busy(within seconds: Double, _ work: @escaping @Sendable () async -> Void) async -> (blocked: Int, ended: Bool) {
            await Task(executorPreference: Motion.Encoding.Reader()) {
                let width = ProcessInfo.processInfo.activeProcessorCount
                let (arrived, release, done) = (DispatchSemaphore(value: 0), DispatchSemaphore(value: 0), DispatchSemaphore(value: 0))
                (0..<width).forEach { _ in
                    Task.detached {
                        arrived.signal()
                        Self.block(release)
                    }
                }
                let blocked = Self.count(arrived, width, within: 10)
                Task(executorPreference: Motion.Encoding.Reader()) {
                    await work()
                    done.signal()
                }
                let ended = Self.count(done, 1, within: seconds) == 1
                (0..<width).forEach { _ in release.signal() }
                return (blocked, ended)
            }.value
        }

        @Test func `a read whose samples cannot come while every thread of the pool is busy ends at its limit`() async throws {
            let movie = try await `Encoding Tests`.written(rate: .thirty)
            let failures = Failures()
            let clock = ContinuousClock()
            let start = clock.now
            let run = await Self.busy(within: 10) {
                // swift-linter:disable:next do throws for typed catch
                // REASON: TaskLocal.withValue throws untyped; the failure is checked by its case below.
                do {
                    try await Motion.Encoding.Wait.$limit.withValue(.seconds(1)) {
                        _ = try await Motion.Encoding.read(movie) { _, _ in }
                    }
                } catch {
                    failures.record(error)
                }
            }
            let waited = clock.now - start
            #expect(run.blocked == ProcessInfo.processInfo.activeProcessorCount)
            #expect(run.ended)
            #expect(failures.all.count == 1)
            #expect(failures.all.allSatisfy { if case .unanswered = $0 as? Motion.Encoding.Error { true } else { false } }, "\(failures.all)")
            #expect(waited < .seconds(10))
        }

        @Test func `a limit fires on time while every thread of the pool is busy`() async {
            let held = DispatchSemaphore(value: 0)
            let failures = Failures()
            let clock = ContinuousClock()
            let start = clock.now
            let run = await Self.busy(within: 5) {
                // swift-linter:disable:next do throws for typed catch
                // REASON: TaskLocal.withValue throws untyped; the failure is checked by its text below.
                do {
                    try await Motion.Encoding.Wait.$limit.withValue(.milliseconds(200)) {
                        _ = try await Motion.Encoding.Wait.answer("a sample", on: Motion.Encoding.Reader()) {
                            Self.block(held)
                            return 7
                        }
                    }
                } catch {
                    failures.record(error)
                }
            }
            let waited = clock.now - start
            held.signal()
            #expect(run.blocked == ProcessInfo.processInfo.activeProcessorCount)
            #expect(run.ended)
            #expect(failures.all.map { "\($0)" } == ["\(Motion.Encoding.Error.unanswered("a sample did not come within 0.2 seconds"))"])
            #expect(waited < .seconds(5))
        }

        @Test func `more reads at once than the machine has processors, beside a write, all end well within the limit`() async throws {
            let movie = try await `Encoding Tests`.written(rate: .thirty, frames: 30)
            let output = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            let reads = ProcessInfo.processInfo.activeProcessorCount + 2
            let clock = ContinuousClock()
            let start = clock.now
            try await withThrowingTaskGroup(of: Cardinal.self) { group in
                (0..<reads).forEach { _ in
                    group.addTask { try await Motion.Encoding.read(movie) { _, _ in } }
                }
                group.addTask {
                    try await Motion.Encoding(width: 320, height: 180, rate: .thirty).write(frames: 30, to: output) { position in
                        await Task.detached { `Encoding Tests`.gradient(position) }.value
                    }
                    return 30
                }
                for try await frames in group { #expect(frames == 30) }
            }
            #expect(clock.now - start < .seconds(10))
        }
    }
}

extension `Encoding Tests`.`Pool Tests` {
    /// The failures work recorded, from any thread.
    final class Failures: Sendable {
        let kept = Mutex<[any Swift.Error]>([])

        func record(_ failure: any Swift.Error) {
            kept.withLock { $0.append(failure) }
        }

        var all: [any Swift.Error] {
            kept.withLock { $0 }
        }
    }
}
