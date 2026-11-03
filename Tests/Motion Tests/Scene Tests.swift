import Motion
import Rational
import Testing

@Suite struct `Scene Tests` {
    @Test func `a scene renders each distinct state once, and every frame shows its state`() {
        let scene = Scene(rate: .thirty, frames: 90) { seconds in seconds < Rational(1) ? 0 : seconds < Rational(2) ? 1 : 0 }
        let plan = scene.plan
        #expect(plan.states == [0, 1])
        #expect(plan.shows.count == 90)
        #expect(plan.shows[29] == 0 && plan.shows[30] == 1 && plan.shows[60] == 0)
    }
}
