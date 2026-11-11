import Motion
import Testing

@Suite struct `Rate Tests` {
    @Test func `the video rates are exact fractions in lowest terms`() throws {
        #expect(Rate.ntsc.perUnit == (try Rational(numerator: 30000, denominator: 1001)))
        #expect(Rate.film.perUnit == (try Rational(numerator: 24000, denominator: 1001)))
        #expect(Rate.thirty == (try Rate(60, per: 2)))
    }

    @Test func `audio samples per frame never drift: five 29.97 frames hold exactly 8008 samples at 48 kHz`() throws {
        let audio = try Rate(48_000)
        let counts = (0..<5).map(Integer.init).map { audio.index(at: Rate.ntsc.start(of: $0 + 1)) - audio.index(at: Rate.ntsc.start(of: $0)) }
        #expect(counts.reduce(0, +) == 8008)
        #expect(Set(counts) == [1601, 1602])
    }

    @Test func `the timecode is drop-frame at 29.97 and non-drop at 30`() throws {
        #expect(try SMPTE_ST_12.Timecode(frame: 1800, at: .ntsc).description == "00:01:00;02")
        #expect(try SMPTE_ST_12.Timecode(frame: 900, at: .thirty).description == "00:00:30:00")
        #expect(try SMPTE_ST_12.Timecode(frame: 24, at: .film).description == "00:00:01:00")
    }
}
