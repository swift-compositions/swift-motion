import AppKit
import Motion
import Motion_Clock
import Motion_Window

/// The process the clock and live host tests launch: a virtual clock needs a process of its own, with the
/// shim library in it from launch. Each mode prints `key=value` lines for its test to read.
let arguments = CommandLine.arguments
switch arguments.dropFirst().first {
case "clock":
    Fixture.clock()
case "late":
    Fixture.late(library: arguments[2])
case "live":
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    _ = Task { @MainActor in
        await Fixture.live(settle: .milliseconds(Int(arguments[2]) ?? 120), frames: Cardinal(UInt(arguments[3]) ?? 6))
        exit(0)
    }
    application.run()
case "restless":
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    _ = Task { @MainActor in
        await Fixture.restless()
        exit(0)
    }
    application.run()
default:
    Fixture.line("error", "no mode")
}
