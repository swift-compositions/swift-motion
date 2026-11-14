import AVFoundation
import Foundation
import ITU_T_H_273
import Motion
import Motion_Encoding
import Test_Apple
import Testing

extension `Encoding Tests` {
    @Suite(.deadline(.seconds(180))) struct `Score Tests` {
        /// A sine tone of 440 Hz at half level, stereo, 48 kHz, written as AAC.
        static func tone(seconds: Int) throws -> URL {
            let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).m4a")
            let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
            let count = 48_000 * seconds
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)))
            buffer.frameLength = AVAudioFrameCount(count)
            guard let channels = unsafe buffer.floatChannelData else { throw CancellationError() }
            (0..<count).forEach { sample in
                let level = Float(0.5 * sin(2 * Double.pi * 440 * Double(sample) / 48_000))
                unsafe channels[0][sample] = level
                unsafe channels[1][sample] = level
            }
            let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2])
            try file.write(from: buffer)
            file.close()
            return url
        }

        /// The time range a track of a movie covers, in seconds.
        static func span(_ url: URL, _ type: AVMediaType) async throws -> (start: Double, end: Double) {
            let track = try #require(try await AVURLAsset(url: url).loadTracks(withMediaType: type).first)
            let range = try await track.load(.timeRange)
            return (range.start.seconds, range.end.seconds)
        }

        @Test(arguments: [Rate.ntsc, Rate.thirty])
        func `a scored movie has one picture of the same frames and one sound under it until the picture ends`(rate: Rate) async throws {
            let picture = try await `Encoding Tests`.written(rate: rate, frames: 30)
            let sound = try Self.tone(seconds: 3)
            let scored = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            let quarter = try Rational(numerator: 1, denominator: 4)
            let cue = Motion.Encoding.Cue(sound, offset: 1, at: quarter, gain: 0.8, rise: try Rational(numerator: 1, denominator: 10), fall: quarter)
            try await Motion.Encoding.score(picture, with: [cue], to: scored)
            let before = try await Motion.Encoding.Inspection(of: picture)
            let after = try await Motion.Encoding.Inspection(of: scored)
            #expect(after.frames == before.frames)
            #expect(after.codec == "avc1")
            #expect(after.rate == rate)
            #expect(after.signal == ITU_T_H_273.Signal.sRGB.carried(by: .bt709))
            #expect(after.sounds == 1)
            let asset = AVURLAsset(url: scored)
            #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
            let video = try await Self.span(scored, .video)
            let audio = try await Self.span(scored, .audio)
            let film = before.duration.approximation
            #expect(abs(video.end - film) < 0.001, "picture ends at \(video.end), not \(film)")
            #expect(abs(audio.end - film) < 0.05, "sound ends at \(audio.end), not \(film)")
            let frames = try await Motion.Decoding(scored).frames(positions: [0, 29])
            let first = try #require(`Encoding Tests`.gradient(0))
            #expect((frames[0].psnr(against: first) ?? 0) > 38)
        }

        @Test func `a cue that enters after the picture ends, or starts after its sound ends, lays nothing and is refused`() async throws {
            let picture = try await `Encoding Tests`.written(rate: .thirty, frames: 30)
            let sound = try Self.tone(seconds: 1)
            let scored = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            await #expect(throws: Motion.Encoding.Error.cue(1)) {
                try await Motion.Encoding.score(picture, with: [Motion.Encoding.Cue(sound), Motion.Encoding.Cue(sound, at: 1)], to: scored)
            }
            await #expect(throws: Motion.Encoding.Error.cue(0)) {
                try await Motion.Encoding.score(picture, with: [Motion.Encoding.Cue(sound, offset: 2)], to: scored)
            }
            #expect(!FileManager.default.fileExists(atPath: scored.path))
        }

        @Test func `a movie reduced for sharing fits its preset, keeps its shape and keeps its frames`() async throws {
            let large = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            try await Motion.Encoding(width: 1280, height: 720, rate: .thirty).write(frames: 3, to: large) { index in
                `Encoding Tests`.gradient(index, width: 1280, height: 720)
            }
            let small = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            try await Motion.Encoding.reduced(large, to: small, as: .height540)
            let inspection = try await Motion.Encoding.Inspection(of: small)
            #expect(inspection.width == 960 && inspection.height == 540)
            #expect(inspection.frames == 3)
        }

        /// A frame of grain, the same for a position in every run, which the encoder cannot make small.
        static func grain(_ index: Ordinal) -> Raster<Motion.Pixel>? {
            var state = UInt64(Int(exactly: index) ?? 0) &* 0x9E37_79B9_7F4A_7C15 | 1
            let bytes = (0..<(320 * 180)).flatMap { _ -> [UInt8] in
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return [UInt8(truncatingIfNeeded: state >> 56), UInt8(truncatingIfNeeded: state >> 48), UInt8(truncatingIfNeeded: state >> 40), 255]
            }
            do throws(Motion.Pixel.Error) {
                return try Raster<Motion.Pixel>(width: 320, height: 180, bytes: bytes)
            } catch {
                return nil
            }
        }

        /// A scored movie of 60 frames of grain at 320 × 180, its sound under it.
        static func scored() async throws -> URL {
            let picture = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            try await Motion.Encoding(width: 320, height: 180, rate: .thirty).write(frames: 60, to: picture) { grain($0) }
            let scored = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            try await Motion.Encoding.score(picture, with: [Motion.Encoding.Cue(try Self.tone(seconds: 2))], to: scored)
            return scored
        }

        static func size(_ url: URL) throws -> Int {
            try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        }

        @Test func `a movie reduced to a limit is within it on file and keeps its shape, frames, rate, tag and sound`() async throws {
            let movie = try await Self.scored()
            let sound = try #require(try await AVURLAsset(url: movie).loadTracks(withMediaType: .audio).first)
            let heard = Int(try await sound.load(.totalSampleDataLength))
            let limit = heard + (try Self.size(movie) - heard) / 2
            let small = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            try await Motion.Encoding.reduced(movie, to: small, within: Cardinal(UInt(limit)))
            #expect(try Self.size(small) <= limit)
            let before = try await Motion.Encoding.Inspection(of: movie)
            let after = try await Motion.Encoding.Inspection(of: small)
            #expect(after.frames == before.frames && after.rate == before.rate && after.duration == before.duration)
            #expect(after.signal == before.signal && after.sounds == 1 && after.codec == "avc1")
            let (wide, tall) = (Int(clamping: after.width), Int(clamping: after.height))
            #expect(abs(wide * 180 - tall * 320) <= 2 * 320, "\(wide) × \(tall) is not the shape of 320 × 180")
            #expect(wide <= 320 && tall <= 180 && wide % 2 == 0 && tall % 2 == 0)
        }

        @Test func `a movie already within the limit is copied as it is`() async throws {
            let movie = try await Self.scored()
            let copy = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            try await Motion.Encoding.reduced(movie, to: copy, within: Cardinal(UInt(try Self.size(movie))))
            #expect(FileManager.default.contentsEqual(atPath: movie.path, andPath: copy.path))
        }

        @Test func `a limit no movie can meet at the smallest size is refused with the fewest bytes written, and nothing is left`() async throws {
            let movie = try await Self.scored()
            let small = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
            await #expect {
                try await Motion.Encoding.reduced(movie, to: small, within: 2000)
            } throws: { error in
                guard case .limit(let limit, let fewest) = error as? Motion.Encoding.Error else { return false }
                return limit == 2000 && fewest > 2000
            }
            #expect(!FileManager.default.fileExists(atPath: small.path))
        }
    }
}
