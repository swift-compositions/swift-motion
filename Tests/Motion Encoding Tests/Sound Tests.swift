#if File
    import AVFoundation
    import Foundation
    import Motion
    import Test_Apple
    import Testing

    @testable import Motion_Encoding

    extension `Encoding Tests` {
        /// Frames written with a sound laid under them in one call, as a film's movie with its music is.
        @Suite(.deadline(.seconds(180))) struct `Sound Tests` {
            /// A directory of its own under the system's temporary directory.
            static func directory() throws -> URL {
                let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                return url
            }

            /// `count` frames of gradients at 30 frames a second written to `url` with the cues under them.
            static func write(_ count: Cardinal, with cues: [Motion.Encoding.Cue], to url: URL) async throws {
                try await Motion.Encoding(width: 320, height: 180, rate: .thirty).write(frames: count, with: cues, to: url) { position in
                    `Encoding Tests`.gradient(position)
                }
            }

            /// The sound of a movie as the mix reads it, interleaved stereo floats at 48 kHz, and the instant its
            /// first sample starts at, read on a reader's thread under the wait limit.
            static func heard(_ url: URL) async throws -> (start: Double, samples: [Float]) {
                try await Motion.Encoding.reading {
                    let asset = AVURLAsset(url: url)
                    let track = try await Motion.Encoding.Wait.load("the sound of \(url.lastPathComponent)", stop: { asset.cancelLoading() }) {
                        try #require(try await asset.loadTracks(withMediaType: .audio).first)
                    }
                    let reader = try AVAssetReader(asset: asset)
                    let output = AVAssetReaderTrackOutput(track: track, outputSettings: Motion.Encoding.mixed)
                    let samples = Motion.Encoding.Wait.Held(reader.outputProvider(for: output))
                    try reader.start()
                    var start: Double?
                    var all: [Float] = []
                    while let buffer = try await Motion.Encoding.Wait.sample("the next sample of \(url.lastPathComponent)", of: samples) {
                        buffer.withUnsafeSampleBuffer { sample in
                            start = start ?? sample.presentationTimeStamp.seconds
                            guard let block = sample.dataBuffer else { return }
                            let length = CMBlockBufferGetDataLength(block)
                            var floats = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
                            floats.withUnsafeMutableBytes { bytes in
                                guard let base = bytes.baseAddress else { return }
                                _ = unsafe CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: base)
                            }
                            all += floats
                        }
                    }
                    return (start ?? 0, all)
                }
            }

            /// The root mean square of a sound's samples from `from` to `to` seconds of the film.
            static func level(_ sound: (start: Double, samples: [Float]), from: Double, to: Double) -> Double {
                let first = Swift.max(0, Int((from - sound.start) * 96_000))
                let last = Swift.min(sound.samples.count, Int((to - sound.start) * 96_000))
                guard last > first else { return 0 }
                let sum = sound.samples[first..<last].reduce(0.0) { $0 + Double($1) * Double($1) }
                return (sum / Double(last - first)).squareRoot()
            }

            /// The level of the test tone, a sine at half its range: half of one over the square root of two.
            static let tone = 0.5 / 2.0.squareRoot()

            @Test func `frames written with a longer sound are those frames with the sound under them, cut where the picture ends`() async throws {
                let directory = try Self.directory()
                let movie = directory.appending(path: "film.mp4")
                try await Self.write(30, with: [Motion.Encoding.Cue(try `Score Tests`.tone(seconds: 3))], to: movie)
                let inspection = try await Motion.Encoding.Inspection(of: movie)
                #expect(inspection.frames == 30 && inspection.rate == .thirty && inspection.sounds == 1 && inspection.codec == "avc1")
                let audio = try await `Score Tests`.span(movie, .audio)
                #expect(abs(audio.end - 1) < 0.05, "sound ends at \(audio.end), not 1")
                let sound = try await Self.heard(movie)
                #expect(abs(Self.level(sound, from: 0.2, to: 0.8) - Self.tone) < 0.03)
                #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["film.mp4"])
                let frames = try await Motion.Decoding(movie).frames(positions: [0, 29])
                #expect((frames[0].psnr(against: try #require(`Encoding Tests`.gradient(0))) ?? 0) > 38)
                let (last, before) = (try #require(`Encoding Tests`.gradient(29)), try #require(`Encoding Tests`.gradient(28)))
                #expect((frames[1].psnr(against: last) ?? 0) > (frames[1].psnr(against: before) ?? .infinity))
            }

            @Test func `a sound shorter than the picture plays once, its track ending with it, and the picture plays on to its end`() async throws {
                let directory = try Self.directory()
                let movie = directory.appending(path: "film.mp4")
                try await Self.write(60, with: [Motion.Encoding.Cue(try `Score Tests`.tone(seconds: 1))], to: movie)
                let inspection = try await Motion.Encoding.Inspection(of: movie)
                #expect(inspection.frames == 60 && inspection.sounds == 1)
                let (audio, video) = (try await `Score Tests`.span(movie, .audio), try await `Score Tests`.span(movie, .video))
                #expect(abs(audio.end - 1) < 0.05, "sound ends at \(audio.end), not 1")
                #expect(abs(video.end - 2) < 0.001, "picture ends at \(video.end), not 2")
                let sound = try await Self.heard(movie)
                #expect(abs(Self.level(sound, from: 0.2, to: 0.8) - Self.tone) < 0.03)
                #expect(sound.start + Double(sound.samples.count) / 96_000 < 1.05, "the sound goes on past its own end")
            }

            @Test func `a sound plays at its gain, rises over its fade in and falls to silence over its fade out at the picture's end`() async throws {
                let directory = try Self.directory()
                let movie = directory.appending(path: "film.mp4")
                let cue = Motion.Encoding.Cue(try `Score Tests`.tone(seconds: 3), gain: 0.32, rise: .half, fall: 1)
                try await Self.write(60, with: [cue], to: movie)
                let sound = try await Self.heard(movie)
                let full = 0.32 * Self.tone
                #expect(abs(Self.level(sound, from: 0.6, to: 0.95) - full) < 0.01)
                #expect(abs(Self.level(sound, from: 0.2, to: 0.3) - full / 2) < 0.01)
                #expect(abs(Self.level(sound, from: 1.45, to: 1.55) - full / 2) < 0.01)
                #expect(Self.level(sound, from: 1.9, to: 1.99) < full / 10)
            }

            @Test func `a cue that lays nothing, a sound that is no file and a file at the output are refused before any frame is asked for`() async throws {
                let directory = try Self.directory()
                let movie = directory.appending(path: "film.mp4")
                let tone = try `Score Tests`.tone(seconds: 1)
                let unasked = { (_: Ordinal) async -> Raster<Motion.Pixel>? in nil }
                let encoding = Motion.Encoding(width: 320, height: 180, rate: .thirty)
                await #expect(throws: Motion.Encoding.Error.cue(1)) {
                    try await encoding.write(frames: 30, with: [Motion.Encoding.Cue(tone), Motion.Encoding.Cue(tone, at: 1)], to: movie, raster: unasked)
                }
                await #expect(throws: Motion.Encoding.Error.cue(0)) {
                    try await encoding.write(frames: 30, with: [Motion.Encoding.Cue(tone, offset: 1)], to: movie, raster: unasked)
                }
                await #expect {
                    try await encoding.write(frames: 30, with: [Motion.Encoding.Cue(directory.appending(path: "none.m4a"))], to: movie, raster: unasked)
                } throws: { error in
                    error is Motion.Encoding.Error && error as? Motion.Encoding.Error != .frame(0)
                }
                #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
                FileManager.default.createFile(atPath: movie.path, contents: Data([1]))
                await #expect(throws: Motion.Encoding.Error.writer("a file is already at film.mp4")) {
                    try await encoding.write(frames: 30, with: [Motion.Encoding.Cue(tone)], to: movie, raster: unasked)
                }
            }
        }
    }
#endif
