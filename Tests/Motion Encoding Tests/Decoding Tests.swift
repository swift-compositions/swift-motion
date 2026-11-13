import AVFoundation
import Foundation
import Motion
import Motion_Encoding
import Test_Apple
import Testing

extension `Encoding Tests` {
    @Suite(.deadline(.seconds(180))) struct `Decoding Tests` {
        @Test func `the frames read back at their positions are what was written, within the codec's noise`() async throws {
            let url = try await `Encoding Tests`.written(rate: .ntsc)
            let movie = try await Motion.Decoding(url)
            #expect(movie.inspection.frames == 6)
            #expect(movie.inspection.rate == .ntsc)
            #expect(movie.inspection.width == 320 && movie.inspection.height == 180)
            let positions: [Ordinal] = [5, 0, 3, 1, 4, 2]
            let frames = try await movie.frames(positions: positions)
            for (position, frame) in zip(positions, frames) {
                let expected = try #require(`Encoding Tests`.gradient(position))
                let psnr = try #require(frame.psnr(against: expected))
                #expect(psnr > 38, "frame \(position): \(psnr) dB")
            }
            let alone = try await movie.frame(position: 2)
            #expect(alone == frames[5])
        }

        @Test func `an instant shows the last frame that starts at or before it, with no tolerance`() async throws {
            let movie = try await Motion.Decoding(try await `Encoding Tests`.written(rate: .ntsc))
            let rate = Rate.ntsc
            let tick = try Rational(numerator: 1, denominator: 30000)
            let instants = [rate.start(of: 2), rate.start(of: 3) - tick, rate.start(of: 3), rate.start(of: 6) - tick, rate.start(of: 6), -tick]
            let shown = try await movie.frames(at: instants)
            let frames = try await movie.frames(positions: [2, 3, 5])
            #expect(shown[0] == frames[0])
            #expect(shown[1] == frames[0])
            #expect(shown[2] == frames[1])
            #expect(shown[3] == frames[2])
            #expect(shown[4] == nil)
            #expect(shown[5] == nil)
        }

        @Test func `a position beyond the movie's frames is refused before anything is decoded`() async throws {
            let movie = try await Motion.Decoding(try await `Encoding Tests`.written(rate: .thirty))
            await #expect(throws: Motion.Encoding.Error.frame(6)) { try await movie.frames(positions: [0, 6]) }
        }
    }
}
