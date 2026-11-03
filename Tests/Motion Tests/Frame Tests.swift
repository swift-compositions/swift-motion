import Motion
import Rational
import SMPTE_ST_12
import Testing

@Suite struct `Frame Tests` {
    @Test func `a frame's centre and start lie in that frame, at any rate, for a day of frames`() {
        for rate in [Frame.Rate.ntsc, .film, .thirty] {
            for index in Swift.stride(from: 0, to: 2_600_000, by: 997) {
                #expect(rate.index(at: rate.centre(of: index)) == index, "\(rate) \(index)")
                #expect(rate.index(at: rate.start(of: index)) == index, "\(rate) \(index)")
            }
        }
    }

    @Test func `audio samples per frame never drift: five 29.97 frames hold exactly 8008 samples at 48 kHz`() {
        let counts = (0..<5).map { Frame.Rate.ntsc.samples(in: $0, at: 48_000) }
        #expect(counts.reduce(0, +) == 8008)
        #expect(Set(counts) == [1601, 1602])
        #expect((0..<900).map { Frame.Rate.thirty.samples(in: $0, at: 48_000) }.allSatisfy { $0 == 1600 })
    }

    @Test func `a rate keeps its frames and seconds in lowest terms, for a container's timescale`() {
        #expect(Frame.Rate.ntsc.numerator == 30000 && Frame.Rate.ntsc.denominator == 1001)
        #expect(Frame.Rate(60, per: 2).numerator == 30 && Frame.Rate(60, per: 2).denominator == 1)
    }

    @Test func `the timecode is drop-frame at 29.97 and non-drop at 30`() {
        #expect(Frame.Rate.ntsc.timecode(of: 1800)?.description == "00:01:00;02")
        #expect(Frame.Rate.thirty.timecode(of: 900)?.description == "00:00:30:00")
        #expect(Frame.Rate.film.timecode(of: 24)?.description == "00:00:01:00")
        #expect(Frame.Rate(15).timecode(of: 0) == nil)
    }
}
