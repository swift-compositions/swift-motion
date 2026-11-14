import AVFoundation
import Foundation
import ITU_T_H_273
import Motion
import Motion_Cache
import Test_Apple
import Testing

@testable import Motion_Encoding

/// AVFoundation's readers and writers wait on CoreMedia's shared queues, and many at once in one process have
/// waited there for good on a small machine, so these tests, and the suites nested in them, run one at a time.
@Suite(.serialized, .deadline(.seconds(600))) struct `Encoding Tests` {
    static func gradient(_ index: Ordinal, width: Int = 320, height: Int = 180) -> Raster<Motion.Pixel>? {
        let shift = (Int(exactly: index) ?? 0) * 8
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        (0..<height).forEach { y in
            (0..<width).forEach { x in
                let at = (y * width + x) * 4
                bytes[at] = UInt8(x * 255 / width)
                bytes[at + 1] = UInt8((y * 200 / height + shift) % 256)
                bytes[at + 2] = UInt8(255 - (x + y) * 255 / (width + height))
            }
        }
        do throws(Motion.Pixel.Error) {
            return try Raster<Motion.Pixel>(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), bytes: bytes)
        } catch {
            return nil
        }
    }

    static func written(rate: Rate, frames: Cardinal = 6) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
        try await Motion.Encoding(width: 320, height: 180, rate: rate).write(frames: frames, to: url) { gradient($0) }
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
        for index in [0, 1, 2, 3, 4, 5] as [Ordinal] {
            let image = try await generator.image(at: CMTime(value: CMTimeValue(2 * (Int(exactly: index) ?? 0) + 1), timescale: 60)).image
            let decoded = try #require(Raster<Motion.Pixel>(image: image))
            let expected = try #require(Self.gradient(index))
            let psnr = try #require(decoded.psnr(against: expected))
            #expect(psnr > 38, "frame \(index): \(psnr) dB")
        }
    }

    @Test func `a movie reads back as what was written: codec, size, frames, exact length, colour tag and sound`() async throws {
        let silent = try await Self.written(rate: .ntsc)
        let inspection = try await Motion.Encoding.Inspection(of: silent)
        #expect(inspection.codec == "avc1")
        #expect(inspection.width == 320 && inspection.height == 180)
        #expect(inspection.frames == 6)
        let length = try Rational(numerator: 6006, denominator: 30000)
        #expect(inspection.duration == length)
        #expect(inspection.signal == ITU_T_H_273.Signal.sRGB.carried(by: .bt709))
        #expect(inspection.sounds == 0)
        let longer = try await Motion.Encoding.Inspection(of: try await Self.written(rate: .thirty, frames: 9))
        let tenths = try Rational(numerator: 3, denominator: 10)
        #expect(longer.frames == 9 && longer.duration == tenths)
    }

    @Test func `a file that is no movie fails to read back with a typed failure`() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
        try Data("not a movie".utf8).write(to: url)
        do throws(Motion.Encoding.Error) {
            _ = try await Motion.Encoding.Inspection(of: url)
            Issue.record("a file that is no movie was inspected")
        } catch {
            guard case .reader = error else {
                Issue.record("\(error)")
                return
            }
        }
        do throws(Motion.Encoding.Error) {
            try await Motion.Encoding.read(url) { _, _ in }
            Issue.record("a file that is no movie was decoded")
        } catch {
            guard case .reader = error else {
                Issue.record("\(error)")
                return
            }
        }
    }

    @Test func `reading a movie hands back every frame in order, each within encoder noise of its raster`() async throws {
        let url = try await Self.written(rate: .ntsc)
        var seen: [Ordinal] = []
        var lowest = Double.infinity
        let count = try await Motion.Encoding.read(url) { frame, raster in
            seen.append(frame)
            let psnr = Self.gradient(frame).flatMap { raster.psnr(against: $0) } ?? 0
            lowest = min(lowest, psnr)
        }
        #expect(count == 6)
        #expect(seen == [0, 1, 2, 3, 4, 5])
        #expect(lowest > 38, "\(lowest) dB")
    }

    /// The queue a thread of Swift's cooperative pool serves, by its label; nil on a thread outside it.
    static func cooperative() -> String? {
        let label = unsafe String(cString: __dispatch_queue_get_label(nil))
        return label.hasSuffix(".cooperative") ? label : nil
    }

    @Test func `a held reader or writer is called on a queue of its own, never a thread of the cooperative pool`() async {
        let held = Motion.Encoding.Wait.Held(0)
        #expect(await held.pooled() == nil)
    }

    @Test func `a signal AVFoundation cannot name is refused, not written untagged`() async {
        let signal = ITU_T_H_273.Signal(primaries: .ebu3213, transfer: .sRGB, matrix: .bt709, range: .limited)
        let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
        await #expect(throws: Motion.Encoding.Error.signal(signal)) {
            try await Motion.Encoding(width: 320, height: 180, rate: .thirty, signal: signal).write(frames: 1, to: url) { Self.gradient($0) }
        }
    }

    @Test func `a frame that is missing or of another size stops the write and is named by its position`() async {
        let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
        let encoding = Motion.Encoding(width: 320, height: 180, rate: .thirty)
        var asked: [Ordinal] = []
        await #expect(throws: Motion.Encoding.Error.frame(2)) {
            try await encoding.write(frames: 4, to: url) { index in
                asked.append(index)
                return index == 2 ? nil : Self.gradient(index)
            }
        }
        #expect(asked == [0, 1, 2])
        let other = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
        await #expect(throws: Motion.Encoding.Error.frame(1)) {
            try await encoding.write(frames: 4, to: other) { index in Self.gradient(index, width: index == 1 ? 318 : 320) }
        }
    }

    @Test func `the bit rate is four bits per pixel per second unless given, and stops at the largest count`() {
        #expect(Motion.Encoding(width: 320, height: 180, rate: .thirty).bitRate == 230_400)
        #expect(Motion.Encoding(width: 320, height: 180, rate: .thirty, bitRate: 1000).bitRate == 1000)
        #expect(Motion.Encoding(width: .max, height: 2, rate: .thirty).bitRate == .max)
        #expect(Motion.Encoding(width: Cardinal(UInt.max / 4), height: 2, rate: .thirty).bitRate == .max)
    }

    @Test func `a size, bit rate or length AVFoundation cannot be told is refused before a frame is asked for`() async {
        let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
        var asked = 0
        await #expect(throws: Motion.Encoding.Error.size(width: .max, height: 180, bits: 1000)) {
            try await Motion.Encoding(width: .max, height: 180, rate: .thirty, bitRate: 1000).write(frames: 1, to: url) { _ in
                asked += 1
                return nil
            }
        }
        await #expect(throws: Motion.Encoding.Error.size(width: 320, height: 180, bits: .max)) {
            try await Motion.Encoding(width: 320, height: 180, rate: .thirty, bitRate: .max).write(frames: 1, to: url) { _ in
                asked += 1
                return nil
            }
        }
        await #expect(throws: Motion.Encoding.Error.length(.max)) {
            try await Motion.Encoding(width: 320, height: 180, rate: .thirty).write(frames: .max, to: url) { _ in
                asked += 1
                return nil
            }
        }
        #expect(asked == 0)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func `a side shorter than a macroblock is refused before a frame is asked for, and one of 16 reads back`() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).mp4")
        var asked = 0
        for (width, height) in [(20, 12), (15, 180), (320, 15)] as [(Cardinal, Cardinal)] {
            let encoding = Motion.Encoding(width: width, height: height, rate: .thirty)
            await #expect(throws: Motion.Encoding.Error.size(width: width, height: height, bits: encoding.bitRate)) {
                try await encoding.write(frames: 1, to: url) { _ in
                    asked += 1
                    return nil
                }
            }
        }
        #expect(asked == 0)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        try await Motion.Encoding(width: 16, height: 16, rate: .thirty).write(frames: 2, to: url) { index in Self.gradient(index, width: 16, height: 16) }
        #expect(try await Motion.Encoding.read(url) { _, _ in } == 2)
    }

    @Test(arguments: [(Rate.ntsc, 30000, 1001), (Rate.thirty, 30, 1)])
    func `muxing a sound keeps the picture's colour tag, timescale and frame durations`(rate: Rate, timescale: Int, ticks: Int) async throws {
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
        try await Motion.Encoding.mux(picture, sound, to: joined)
        let box = try Box(joined)
        #expect(box.colour?.codes == "1-13-1")
        #expect(box.timescale("mdhd") == timescale)
        #expect(box.durations?.ticks == ticks)
        let sounds = try await Motion.Encoding.Inspection(of: joined).sounds
        #expect(sounds == 1)
        #expect(try await AVURLAsset(url: joined).load(.duration) == CMTime(value: CMTimeValue(30 * ticks), timescale: CMTimeScale(timescale)))
    }
}

extension Motion.Encoding.Wait.Held {
    /// The cooperative queue a call on the held object runs on, or nil outside the pool.
    func pooled() -> String? {
        `Encoding Tests`.cooperative()
    }
}
