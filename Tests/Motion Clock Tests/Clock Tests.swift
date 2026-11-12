import Foundation
import Test_Apple
import Testing

/// A virtual clock is a property of a whole process, so every test here launches the fixture process and
/// reads what it found.
@Suite(.deadline(.seconds(120))) struct `Clock Tests` {
    @Test func `until the clock is frozen the machine's clock runs through, and once frozen the four readings stand still while the wall clock runs`() {
        let found = Fixture.run(["clock"], inserting: true)
        #expect(found["status"] == ["exit 0"] && found["stderr"] == nil, "\(found["status"] ?? []) \(found["stderr"] ?? [])")
        #expect(found["running"] == ["true"])
        #expect(found["still"] == ["true"])
        #expect(found["wall"] == ["true"])
        #expect(found["zero"] == ["true"])
    }

    @Test func `advancing moves all four readings by exactly the time advanced, and they hold there`() {
        let found = Fixture.run(["clock"], inserting: true)
        #expect(found["second"] == ["done"])
        #expect(found["absolute"] == ["1000000000.0"])
        #expect(found["continuous"] == ["1000000000.0"])
        #expect(found["approximate"] == ["1000000000.0"])
        #expect(found["media"] == ["true"])
        #expect(found["elapsed"] == ["true"])
        #expect(found["held"] == ["true"])
    }

    @Test func `the clock never runs backwards, counts whole nanoseconds, and a refused advance moves nothing`() {
        let found = Fixture.run(["clock"], inserting: true)
        #expect(found["backwards"] == ["backwards"])
        #expect(found["negative"] == ["backwards"])
        #expect(found["beyond"] == ["beyond"])
        #expect(found["unmoved"] == ["true"])
        #expect(found["same"] == ["done"])
        #expect(found["cut"] == ["done"])
        #expect(found["whole"] == ["true"])
    }

    @Test func `a frame starts at its exact time cut to whole nanoseconds, so 30000 frames at 29.97 end at 1001 seconds`() {
        let found = Fixture.run(["clock"], inserting: true)
        #expect(found["frames"] == ["true"])
        #expect(found["starts"] == ["beyond"])
        #expect(found["frame"] == ["done"])
        #expect(found["exact"] == ["true"])
    }

    @Test func `a second clock is a second handle on the same one`() {
        let found = Fixture.run(["clock"], inserting: true)
        #expect(found["kept"] == ["true"])
        #expect(found["shared"] == ["true"])
        #expect(found["other"] == ["done"])
    }

    @Test func `without the shim library in the process there is no clock, and nothing is frozen`() {
        let found = Fixture.run(["clock"], inserting: false)
        #expect(found["error"] == ["absent"])
        #expect(found["running"] == ["true"])
        #expect(found["still"] == nil)
    }

    @Test func `a shim library loaded after launch is refused as unhooked, and nothing is frozen`() throws {
        let library = try #require(Fixture.library)
        let found = Fixture.run(["late", library], inserting: false)
        #expect(found["loaded"] == ["true"])
        #expect(found["clock"] == ["unhooked"])
        #expect(found["running"] == ["true"])
    }
}
