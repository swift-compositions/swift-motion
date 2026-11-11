import Motion
import Rational
import Testing

@Suite struct `Scene Tests` {
    @Test func `a scene renders each distinct state once, and every frame shows its state`() {
        let scene = Motion.Scene(rate: .thirty, frames: 90) { seconds in seconds < Rational(1) ? 0 : seconds < Rational(2) ? 1 : 0 }
        let plan = scene.plan
        #expect(plan.states == [0, 1])
        #expect(plan.shows.count == 90)
        #expect(plan.shows[29] == 0 && plan.shows[30] == 1 && plan.shows[60] == 0)
    }

    @Test func `a plan's shows are positions in its states, and a scene of no frames plans nothing`() throws {
        let cut = try Rational(numerator: 1, denominator: 15)
        let scene = Motion.Scene(rate: .thirty, frames: 4) { seconds in seconds < cut ? "b" : "a" }
        #expect(scene.plan.states == ["b", "a"])
        #expect(scene.plan.shows == [0, 0, 1, 1])
        #expect(scene.plan.shows.map { scene.plan.states[Int(bitPattern: $0)] } == ["b", "b", "a", "a"])
        let empty = Motion.Scene(rate: .thirty, frames: 0) { _ in 0 }.plan
        #expect(empty.states.isEmpty && empty.shows.isEmpty)
    }
}
