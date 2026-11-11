import AppKit
import Motion
import Motion_Clock
import Motion_Window
import QuartzCore

enum Fixture {}

extension Fixture {
    static func line(_ key: String, _ value: Any) { print("\(key)=\(value)") }

    /// The four readings the shim library replaces.
    static func readings() -> [Double] {
        [Double(mach_absolute_time()), Double(mach_continuous_time()), Double(mach_approximate_time()), CACurrentMediaTime()]
    }

    /// Wall time in seconds, which no clock here replaces.
    static func wall() -> Double {
        var now = timeval()
        unsafe gettimeofday(&now, nil)
        return Double(now.tv_sec) + Double(now.tv_usec) / 1_000_000
    }

    /// Machine ticks as nanoseconds.
    static func nanoseconds(_ ticks: Double) -> Double {
        var timebase = mach_timebase_info_data_t()
        unsafe mach_timebase_info(&timebase)
        return ticks * Double(timebase.numer) / Double(timebase.denom)
    }

    static func attempt(_ key: String, _ body: () throws(Motion.Clock.Error) -> Void) {
        do throws(Motion.Clock.Error) {
            try body()
            line(key, "done")
        } catch {
            line(key, error)
        }
    }

    static func clock() {
        let before = readings()
        usleep(20_000)
        line("running", zip(before, readings()).allSatisfy { $0 < $1 })
        let clock: Motion.Clock
        do throws(Motion.Clock.Error) {
            clock = try Motion.Clock()
        } catch {
            line("error", error)
            return
        }
        let frozen = readings()
        let started = wall()
        usleep(40_000)
        line("still", frozen == readings())
        line("wall", wall() - started > 0.03)
        line("zero", clock.elapsed == .zero)
        attempt("second") { () throws(Motion.Clock.Error) in try clock.advance(to: .seconds(1)) }
        let moved = readings()
        line("absolute", nanoseconds(moved[0] - frozen[0]))
        line("continuous", nanoseconds(moved[1] - frozen[1]))
        line("approximate", nanoseconds(moved[2] - frozen[2]))
        line("media", abs(moved[3] - frozen[3] - 1) < 0.000_001)
        line("elapsed", clock.elapsed == .seconds(1))
        usleep(40_000)
        line("held", moved == readings())
        attempt("backwards") { () throws(Motion.Clock.Error) in try clock.advance(to: .milliseconds(999)) }
        attempt("negative") { () throws(Motion.Clock.Error) in try clock.advance(to: .seconds(-1)) }
        attempt("beyond") { () throws(Motion.Clock.Error) in try clock.advance(to: .seconds(Int64.max)) }
        line("unmoved", clock.elapsed == .seconds(1) && moved == readings())
        attempt("same") { () throws(Motion.Clock.Error) in try clock.advance(to: .seconds(1)) }
        attempt("cut") { () throws(Motion.Clock.Error) in try clock.advance(to: .seconds(2) + .nanoseconds(5) + Duration(secondsComponent: 0, attosecondsComponent: 999_999_999)) }
        line("whole", clock.elapsed == .seconds(2) + .nanoseconds(5))
        attempt("starts") { () throws(Motion.Clock.Error) in
            let starts = try [1, 2, 3, 30_000].map { (frame: Ordinal) throws(Motion.Clock.Error) in try Motion.Clock.start(of: frame, at: .ntsc) }
            line("frames", starts == [.nanoseconds(33_366_666), .nanoseconds(66_733_333), .nanoseconds(100_100_000), .seconds(1001)])
            _ = try Motion.Clock.start(of: Ordinal(UInt.max), at: .ntsc)
        }
        attempt("frame") { () throws(Motion.Clock.Error) in try clock.advance(to: 30_000, at: .ntsc) }
        line("exact", clock.elapsed == .seconds(1001))
        attempt("other") { () throws(Motion.Clock.Error) in
            let other = try Motion.Clock()
            line("kept", other.elapsed == .seconds(1001) && clock.elapsed == .seconds(1001))
            try other.advance(to: .seconds(1002))
            line("shared", clock.elapsed == .seconds(1002))
        }
    }

    /// Loads the shim library after launch, when no call can be routed through it any more.
    static func late(library: String) {
        line("loaded", unsafe dlopen(library, RTLD_NOW) != nil)
        attempt("clock") { () throws(Motion.Clock.Error) in _ = try Motion.Clock() }
        let before = readings()
        usleep(20_000)
        line("running", zip(before, readings()).allSatisfy { $0 < $1 })
    }
}
