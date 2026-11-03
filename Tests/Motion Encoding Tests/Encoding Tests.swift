import AVFoundation
import Foundation
import ITU_T_H_273
import Motion
import Motion_Cache
import Motion_Encoding
import Testing

@Suite struct `Encoding Tests` {
    static func gradient(_ index: Int, width: Int = 320, height: Int = 180) -> Raster {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let at = (y * width + x) * 4
                bytes[at] = UInt8(x * 255 / width)
                bytes[at + 1] = UInt8((y * 200 / height + index * 8) % 256)
                bytes[at + 2] = UInt8(255 - (x + y) * 255 / (width + height))
            }
        }
        // swift-linter:disable:next try optional
        // REASON: an opaque gradient is always a valid raster.
        return try! Raster(width: width, height: height, bytes: bytes)
    }

    static func written(rate: Frame.Rate, frames: Int = 6) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
        try await Encoding(width: 320, height: 180, rate: rate).write(frames: frames, to: url) { gradient($0) }
        return url
    }

    @Test func `frames rendered in sRGB are tagged 1-13-1 at limited range`() async throws {
        let box = try Box(try await Self.written(rate: .thirty))
        let colour = try #require(box.colour)
        #expect(colour.codes == "1-13-1")
        #expect(!colour.full)
    }

    @Test func `the timescale is the rate's own, so 29.97 frames last exactly 1001 ticks of 30000`() async throws {
        let ntsc = try Box(try await Self.written(rate: .ntsc))
        #expect(ntsc.timescale("mvhd") == 30000)
        #expect(ntsc.timescale("mdhd") == 30000)
        #expect(ntsc.durations?.ticks == 1001)
        let thirty = try Box(try await Self.written(rate: .thirty))
        #expect(thirty.timescale("mdhd") == 30)
        #expect(thirty.durations?.count == 6 && thirty.durations?.ticks == 1)
    }

    @Test func `decoded frames match their rasters within encoder noise`() async throws {
        let url = try await Self.written(rate: .thirty)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        for index in 0..<6 {
            let image = try await generator.image(at: CMTime(value: CMTimeValue(2 * index + 1), timescale: 60)).image
            let decoded = try #require(Raster(image: image))
            let psnr = Raster.psnr(decoded, Self.gradient(index))
            #expect(psnr > 38, "frame \(index): \(psnr) dB")
        }
    }

    @Test func `a signal AVFoundation cannot name is refused, not written untagged`() async {
        let signal = ITU_T_H_273.Signal(primaries: .ebu3213, transfer: .sRGB, matrix: .bt709, range: .limited)
        let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
        await #expect(throws: Encoding.Error.signal(signal)) {
            try await Encoding(width: 320, height: 180, rate: .thirty, signal: signal).write(frames: 1, to: url) { Self.gradient($0) }
        }
    }

    @Test(arguments: [(Frame.Rate.ntsc, 30000, 1001), (Frame.Rate.thirty, 30, 1)])
    func `muxing a sound keeps the picture's colour tag, timescale and frame durations`(rate: Frame.Rate, timescale: Int, ticks: Int) async throws {
        let picture = try await Self.written(rate: rate, frames: 30)
        let sound = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).m4a")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000))
        buffer.frameLength = 48_000
        do {
            let file = try AVAudioFile(forWriting: sound, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2])
            try file.write(from: buffer)
            file.close()
        }
        let joined = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
        try await Encoding.mux(picture, sound, to: joined)
        let box = try Box(joined)
        #expect(box.colour?.codes == "1-13-1")
        #expect(box.timescale("mdhd") == timescale)
        #expect(box.durations?.ticks == ticks)
        #expect(try await AVURLAsset(url: joined).load(.duration) == CMTime(value: CMTimeValue(30 * ticks), timescale: CMTimeScale(timescale)))
    }
}
