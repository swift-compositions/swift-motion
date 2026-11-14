public import AVFoundation
public import Motion

extension Motion {
    /// How frames become an H.264 MP4: size, exact rate, colour signal and bit rate.
    ///
    /// The movie's timescale is the rate's own numerator, so each frame lasts exactly
    /// `denominator` ticks (1001 at 30000/1001), and the `colr` box carries the H.273 signal.
    public struct Encoding: Sendable, Hashable {
        public var width: Cardinal
        public var height: Cardinal
        public var rate: Rate
        public var signal: ITU_T_H_273.Signal
        /// Bits per second.
        public var bitRate: Cardinal

        /// Frames rendered in sRGB, carried through the BT.709 matrix, are tagged 1-13-1 at limited range.
        /// Without a bit rate it is four bits per pixel per second, stopping at the largest count.
        public init(
            width: Cardinal,
            height: Cardinal,
            rate: Rate,
            signal: ITU_T_H_273.Signal = ITU_T_H_273.Signal.sRGB.carried(by: .bt709),
            bitRate: Cardinal? = nil
        ) {
            self.width = width
            self.height = height
            self.rate = rate
            self.signal = signal
            self.bitRate = bitRate ?? Self.bits(width: width, height: height)
        }
    }
}

extension Motion.Encoding {
    /// Four bits per pixel per second, stopping at the largest count.
    static func bits(width: Cardinal, height: Cardinal) -> Cardinal {
        guard let columns = Int(exactly: width), let rows = Int(exactly: height) else { return .max }
        let (pixels, wide) = columns.multipliedReportingOverflow(by: rows)
        let (bits, long) = pixels.multipliedReportingOverflow(by: 4)
        return wide || long ? .max : Cardinal(UInt(bits))
    }

    /// The shortest side a movie may have: one macroblock, 16 pixels. AVFoundation's software H.264 encoder,
    /// which it takes where there is no hardware encoder or the hardware one is busy, writes a picture with a
    /// shorter side as a movie that no decoder reads back.
    public static let side: Cardinal = 16

    /// The width, height and bit rate as AVFoundation takes them.
    func sizes() throws(Motion.Encoding.Error) -> (width: Int, height: Int, bits: Int) {
        guard width >= Self.side, height >= Self.side, let wide = Int(exactly: width), let tall = Int(exactly: height), let bits = Int(exactly: bitRate) else {
            throw .size(width: width, height: height, bits: bitRate)
        }
        return (wide, tall, bits)
    }

    /// AVFoundation's colour properties for the signal, or nil where it has no name for a code point.
    var properties: [String: String]? {
        let primaries: String? =
            switch signal.primaries {
            case .bt709: AVVideoColorPrimaries_ITU_R_709_2
            case .bt2020: AVVideoColorPrimaries_ITU_R_2020
            case .displayP3: AVVideoColorPrimaries_P3_D65
            default: nil
            }
        let transfer: String? =
            switch signal.transfer {
            case .bt709, .bt601: AVVideoTransferFunction_ITU_R_709_2
            case .sRGB: AVVideoTransferFunction_IEC_sRGB
            case .pq: AVVideoTransferFunction_SMPTE_ST_2084_PQ
            case .hlg: AVVideoTransferFunction_ITU_R_2100_HLG
            case .linear: AVVideoTransferFunction_Linear
            default: nil
            }
        let matrix: String? =
            switch signal.matrix {
            case .bt709: AVVideoYCbCrMatrix_ITU_R_709_2
            case .bt601: AVVideoYCbCrMatrix_ITU_R_601_4
            case .bt2020: AVVideoYCbCrMatrix_ITU_R_2020
            default: nil
            }
        guard let primaries, let transfer, let matrix, signal.range == .limited else { return nil }
        return [AVVideoColorPrimariesKey: primaries, AVVideoTransferFunctionKey: transfer, AVVideoYCbCrMatrixKey: matrix]
    }

    /// Encodes `count` frames, asking `raster` for each position in order, from zero.
    public func write(frames count: Cardinal, to url: URL, raster: (Ordinal) async -> Raster<Motion.Pixel>?) async throws(Motion.Encoding.Error) {
        guard let properties else { throw .signal(signal) }
        _ = try sizes()
        _ = try end(of: count)
        // swift-linter:disable:next do throws for typed catch
        // REASON: AVAssetWriter, its pixel buffer receiver and CVMutablePixelBuffer throw untyped; their errors become Error.writer.
        do {
            try await Self.reading { try await encode(frames: count, to: url, properties: properties, raster: raster) }
        } catch let failure as Motion.Encoding.Error {
            throw failure
        } catch {
            throw .writer("\(error)")
        }
    }

    // swift-linter:disable:next untyped throws
    // REASON: it calls AVAssetWriter, its pixel buffer receiver and CVMutablePixelBuffer, which throw untyped; write(frames:to:raster:) types them.
    func encode(frames count: Cardinal, to url: URL, properties: [String: String], raster: (Ordinal) async -> Raster<Motion.Pixel>?) async throws {
        let sizes = try sizes()
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        writer.movieTimeScale = try timescale()
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: sizes.width,
                AVVideoHeightKey: sizes.height,
                AVVideoColorPropertiesKey: properties,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: sizes.bits,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ],
            ]
        )
        input.mediaTimeScale = try timescale()
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: sizes.width, height: sizes.height),
            compatibility: [.cgBitmapContext, .cgImage]
        )
        let receiver = Wait.Held(writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes))
        let name = url.lastPathComponent
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        var index = Ordinal.zero
        while index < Ordinal(count) {
            guard let frame = await raster(index), frame.width == width, frame.height == height else { throw Motion.Encoding.Error.frame(index) }
            let at = try time(of: index)
            try await Wait.answer("the writer to take frame \(index) of \(name)", on: receiver.reader) {
                try await receiver.append(frame, at: at, attributes: attributes)
            }
            index += Cardinal.one
        }
        await receiver.finish()
        writer.endSession(atSourceTime: try end(of: count))
        try await Self.finish(Wait.Held(writer), name)
    }

    /// The movie's timescale: the rate's numerator in lowest terms, so a frame lasts its denominator in ticks.
    func timescale() throws(Motion.Encoding.Error) -> CMTimeScale {
        guard let scale = rate.frequency.numerator.exactly(CMTimeScale.self) else { throw .rate(rate) }
        return scale
    }

    /// When the frame at `index` starts, exactly, in the movie's timescale.
    func time(of index: Ordinal) throws(Motion.Encoding.Error) -> CMTime {
        try end(of: Cardinal(index))
    }

    /// When `count` frames end, exactly, in the movie's timescale: `count` times the rate's denominator in ticks.
    func end(of count: Cardinal) throws(Motion.Encoding.Error) -> CMTime {
        let scale = try timescale()
        guard let frames = Int(exactly: count), let ticks = (Integer(frames) * rate.frequency.denominator).exactly(CMTimeValue.self) else { throw .length(count) }
        return CMTime(value: ticks, timescale: scale)
    }

    /// Copies a frame's pixels into a pixel buffer's plane straight from their memory: in one piece when the
    /// plane's rows are packed as the raster's are, and row by row past the padding otherwise.
    static func copy(_ raster: Raster<Motion.Pixel>, into buffer: inout CVMutablePixelBuffer) {
        unsafe buffer.accessUnsafeMutableRawPlaneBytes { planes in
            guard let plane = unsafe planes.first else { return }
            guard let columns = Int(exactly: raster.width), let rows = Int(exactly: raster.height) else { return }
            let row = columns * 4
            let stride = unsafe plane.properties.bytesPerRow
            raster.pixels.withUnsafeBytes { source in
                if stride == row {
                    unsafe UnsafeMutableRawBufferPointer(rebasing: plane.bytes[0..<source.count]).copyMemory(from: source)
                    return
                }
                (0..<rows).forEach { line in
                    let start = line * row
                    unsafe UnsafeMutableRawBufferPointer(rebasing: plane.bytes[(line * stride)..<(line * stride + row)])
                        .copyMemory(from: UnsafeRawBufferPointer(rebasing: source[start..<(start + row)]))
                }
            }
        }
    }
}

extension Motion.Encoding {
    /// Joins a silent picture and a sound into one MP4 without re-encoding either.
    public static func mux(_ silent: URL, _ sound: URL, to url: URL) async throws(Motion.Encoding.Error) {
        // swift-linter:disable:next do throws for typed catch
        // REASON: AVMutableComposition and AVAssetExportSession throw untyped; their errors become Error.writer.
        do {
            try await reading { try await join(silent, sound, to: url) }
        } catch let failure as Motion.Encoding.Error {
            throw failure
        } catch {
            throw .writer("\(error)")
        }
    }

    // swift-linter:disable:next untyped throws
    // REASON: loadTracks, insertTimeRange and export(to:as:) throw untyped; mux(_:_:to:) types them.
    static func join(_ silent: URL, _ sound: URL, to url: URL) async throws {
        let picture = AVURLAsset(url: silent)
        let audio = AVURLAsset(url: sound)
        let names = "\(silent.lastPathComponent) and \(sound.lastPathComponent)"
        let loaded = try await Wait.load(
            "the tracks of \(names)",
            stop: {
                picture.cancelLoading()
                audio.cancelLoading()
            }
        ) {
            let frames = try await picture.loadTracks(withMediaType: .video).first
            return (
                duration: try await picture.load(.duration),
                frames: frames,
                scale: try await frames?.load(.naturalTimeScale),
                samples: try await audio.loadTracks(withMediaType: .audio).first,
                heard: try await audio.load(.duration)
            )
        }
        let (duration, heard) = (loaded.duration, loaded.heard)
        let composition = AVMutableComposition()
        guard
            let frames = loaded.frames,
            let scale = loaded.scale,
            let samples = loaded.samples,
            let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let sound = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw Motion.Encoding.Error.writer("\(silent.lastPathComponent) or \(sound.lastPathComponent) has no track") }
        video.naturalTimeScale = scale
        try video.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: frames, at: .zero)
        let length = min(duration, heard)
        try sound.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: samples, at: .zero)
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw Motion.Encoding.Error.writer("no passthrough export session")
        }
        session.shouldOptimizeForNetworkUse = true
        try await Wait.export("the joining of \(names)", of: session, to: url)
    }
}

extension Motion.Encoding {
    /// Decodes every frame of the movie at `url`, in order, and hands each to `each` with its position.
    /// Returns the number of frames decoded. A file that is no movie, or has no picture, fails with `.reader`.
    @discardableResult
    public static func read(_ url: URL, each: (Ordinal, Raster<Motion.Pixel>) async -> Void) async throws(Motion.Encoding.Error) -> Cardinal {
        // swift-linter:disable:next do throws for typed catch
        // REASON: AVURLAsset's loaders and AVAssetReader throw untyped; their errors become Error.reader.
        do {
            return try await reading { try await decoded(url, each: each) }
        } catch let failure as Motion.Encoding.Error {
            throw failure
        } catch {
            throw .reader("\(error)")
        }
    }

    // swift-linter:disable:next untyped throws
    // REASON: it calls AVURLAsset's loaders and AVAssetReader, which throw untyped; read(_:each:) types them.
    /// `read(_:each:)`, each sample asked through `Wait.sample`.
    static func decoded(_ url: URL, each: (Ordinal, Raster<Motion.Pixel>) async -> Void) async throws -> Cardinal {
        let asset = AVURLAsset(url: url)
        let name = url.lastPathComponent
        let stop: @Sendable () -> Void = { asset.cancelLoading() }
        let track = try await Wait.load("the picture of \(name)", stop: stop) {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw Motion.Encoding.Error.reader("\(name) has no picture")
            }
            return track
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let samples = Motion.Encoding.Wait.Held(reader.outputProvider(for: output))
        try reader.start()
        var frame = Ordinal.zero
        while true {
            guard let buffer = try await Wait.sample("the next frame of \(name)", of: samples, stop: stop) else { break }
            guard let raster = buffer.withUnsafeSampleBuffer({ sample in sample.imageBuffer.flatMap(Self.raster) }) else { continue }
            await each(frame, raster)
            frame += Cardinal.one
        }
        guard reader.status == .completed else { throw Motion.Encoding.Error.reader(reader.error?.localizedDescription ?? "not read to the end") }
        return Cardinal(frame)
    }

    /// The pixels of a decoded BGRA frame, checked and copied straight out of the locked buffer.
    static func raster(_ buffer: CVPixelBuffer) -> Raster<Motion.Pixel>? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = unsafe CVPixelBufferGetBaseAddress(buffer),
            let width = UInt(exactly: CVPixelBufferGetWidth(buffer)),
            let height = UInt(exactly: CVPixelBufferGetHeight(buffer)),
            let stride = UInt(exactly: CVPixelBufferGetBytesPerRow(buffer))
        else { return nil }
        let memory = unsafe UnsafeRawBufferPointer(start: base, count: CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer))
        do throws(Motion.Pixel.Error) {
            return try Raster<Motion.Pixel>(width: Cardinal(width), height: Cardinal(height), stride: Cardinal(stride), bytes: unsafe RawSpan(_unsafeBytes: memory))
        } catch {
            return nil
        }
    }
}

extension Motion.Encoding {
    /// A time as an exact fraction of seconds, or nil for one that is not a number of ticks.
    static func instant(_ time: CMTime) -> Rational? {
        guard time.isNumeric, time.timescale > 0 else { return nil }
        do throws(Rational.Error) {
            return try Rational(numerator: Integer(time.value), denominator: Integer(time.timescale))
        } catch {
            return nil
        }
    }

    /// An instant in seconds as a `CMTime`, exactly, or `.instant` when its numerator or denominator does not fit.
    static func time(_ instant: Rational) throws(Motion.Encoding.Error) -> CMTime {
        guard let value = instant.numerator.exactly(CMTimeValue.self), let scale = instant.denominator.exactly(CMTimeScale.self) else {
            throw .instant(instant)
        }
        return CMTime(value: value, timescale: scale)
    }
}

extension Motion.Encoding {
    /// Lays cues of sound under a movie's picture and writes the result as an MP4 at `url`, where no file may be.
    ///
    /// The picture is copied sample for sample, not encoded again, so it keeps its codec, colour tag, timescale
    /// and frame durations. The cues are mixed into one sound, each from its offset, entering at its film time,
    /// at its gain with its fades, as `Cue` says, and encoded as stereo AAC at 48 kHz; before the first cue
    /// enters the sound is silent, and nothing plays past the picture's end. A cue that lays no sound under the
    /// picture fails with `.cue` and its position, and a time AVFoundation cannot be told exactly with
    /// `.instant`, both before anything is written; a movie with no picture fails with `.reader`.
    public static func score(_ picture: URL, with cues: [Cue], to url: URL) async throws(Motion.Encoding.Error) {
        // swift-linter:disable:next do throws for typed catch
        // REASON: AVMutableComposition, AVAssetReader and AVAssetWriter throw untyped; their errors become Error.writer.
        do {
            try await reading { try await lay(cues, under: picture, to: url) }
        } catch let failure as Motion.Encoding.Error {
            throw failure
        } catch {
            throw .writer("\(error)")
        }
    }

    // swift-linter:disable:next untyped throws
    // REASON: loadTracks, insertTimeRange, AVAssetReader and AVAssetWriter throw untyped; score(_:with:to:) types them.
    static func lay(_ cues: [Cue], under picture: URL, to url: URL) async throws {
        let movie = AVURLAsset(url: picture)
        let name = picture.lastPathComponent
        let (frames, format, range, scale) = try await Wait.load("the picture of \(name)", stop: { movie.cancelLoading() }) {
            guard let frames = try await movie.loadTracks(withMediaType: .video).first, let format = try await frames.load(.formatDescriptions).first else {
                throw Motion.Encoding.Error.reader("\(name) has no picture")
            }
            return (frames, format, try await frames.load(.timeRange), try await frames.load(.naturalTimeScale))
        }
        guard let film = instant(range.end) else { throw Motion.Encoding.Error.reader("\(name) states no length") }
        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Motion.Encoding.Error.writer("no picture track could be made")
        }
        video.naturalTimeScale = scale
        try video.insertTimeRange(CMTimeRange(start: .zero, duration: range.end), of: frames, at: .zero)
        var parameters: [AVMutableAudioMixInputParameters] = []
        var sounds: [AVURLAsset] = []
        for (index, cue) in cues.enumerated() {
            let sound = AVURLAsset(url: cue.sound)
            sounds.append(sound)
            let loaded = try await Wait.load("the sound of cue \(index), \(cue.sound.lastPathComponent)", stop: { sound.cancelLoading() }) {
                (samples: try await sound.loadTracks(withMediaType: .audio).first, heard: instant(try await sound.load(.duration)))
            }
            guard let samples = loaded.samples, let heard = loaded.heard else {
                throw Motion.Encoding.Error.cue(Ordinal(UInt(index)))
            }
            let length = Swift.min(heard - cue.offset, film - cue.entry)
            guard cue.offset >= .zero, cue.entry >= .zero, length > .zero,
                let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { throw Motion.Encoding.Error.cue(Ordinal(UInt(index))) }
            try track.insertTimeRange(CMTimeRange(start: try time(cue.offset), duration: try time(length)), of: samples, at: try time(cue.entry))
            parameters.append(try levels(of: cue, lasting: length, on: track))
        }
        guard !parameters.isEmpty else { throw Motion.Encoding.Error.cue(.zero) }
        let mix = AVMutableAudioMix()
        mix.inputParameters = parameters
        let reader = try AVAssetReader(asset: composition)
        let pictures = AVAssetReaderTrackOutput(track: video, outputSettings: nil)
        let mixed = AVAssetReaderAudioMixOutput(audioTracks: composition.tracks(withMediaType: .audio), audioSettings: Self.mixed)
        mixed.audioMix = mix
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        writer.movieTimeScale = scale
        let copied = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: format)
        copied.mediaTimeScale = scale
        let encoded = AVAssetWriterInput(mediaType: .audio, outputSettings: Self.aac)
        let (pictureProvider, soundProvider) = (reader.outputProvider(for: pictures), reader.outputProvider(for: mixed))
        let (pictureReceiver, soundReceiver) = (writer.inputReceiver(for: copied), writer.inputReceiver(for: encoded))
        let stop: @Sendable () -> Void = { [sounds] in
            movie.cancelLoading()
            sounds.forEach { $0.cancelLoading() }
        }
        try reader.start()
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        async let picturesCopied: Void = pump(pictureProvider, into: pictureReceiver, of: "the picture of \(name)", stop: stop)
        async let soundsEncoded: Void = pump(soundProvider, into: soundReceiver, of: "the sound under \(name)", stop: stop)
        _ = try await (picturesCopied, soundsEncoded)
        writer.endSession(atSourceTime: range.end)
        try await Self.finish(Wait.Held(writer), url.lastPathComponent)
    }

    /// A cue's level over its stretch: its gain, reached from silence over its fade in and left for silence
    /// over its fade out, two fades longer together than the stretch each cut to half of it.
    static func levels(of cue: Cue, lasting length: Rational, on track: AVCompositionTrack) throws(Motion.Encoding.Error) -> AVMutableAudioMixInputParameters {
        let half = length * .half
        let long = cue.rise + cue.fall > length
        let rise = long ? Swift.min(cue.rise, half) : Swift.max(cue.rise, .zero)
        let fall = long ? Swift.min(cue.fall, half) : Swift.max(cue.fall, .zero)
        let levels = AVMutableAudioMixInputParameters(track: track)
        levels.setVolume(rise > .zero ? 0 : cue.gain, at: .zero)
        if rise > .zero {
            levels.setVolumeRamp(fromStartVolume: 0, toEndVolume: cue.gain, timeRange: CMTimeRange(start: try time(cue.entry), duration: try time(rise)))
        }
        if fall > .zero {
            levels.setVolumeRamp(fromStartVolume: cue.gain, toEndVolume: 0, timeRange: CMTimeRange(start: try time(cue.entry + length - fall), duration: try time(fall)))
        }
        return levels
    }

    /// Every sample a reader's output gives, appended to a writer's input in order, and the input finished.
    /// A wait past its limit is `.unanswered`, naming `what`; any other failure to read or to append is `.writer`.
    static func pump(
        _ provider: sending AVAssetReaderOutput.Provider<CMReadySampleBuffer<CMSampleBuffer.DynamicContent>>,
        into receiver: sending AVAssetWriterInput.SampleBufferReceiver,
        of what: String,
        stop: @escaping @Sendable () -> Void
    ) async throws(Motion.Encoding.Error) {
        // swift-linter:disable:next do throws for typed catch
        // REASON: the provider's next() and the receiver's append throw untyped; their errors become Error.writer.
        do {
            try await copy(provider, into: receiver, of: what, stop: stop)
        } catch let failure as Motion.Encoding.Error {
            throw failure
        } catch {
            throw .writer("\(error)")
        }
    }

    // swift-linter:disable:next untyped throws
    // REASON: the provider's next() and the receiver's append throw untyped; pump(_:into:) types them.
    /// `pump(_:into:of:stop:)`: the provider and the receiver each held on a queue of their own.
    static func copy(
        _ provider: sending Samples,
        into receiver: sending AVAssetWriterInput.SampleBufferReceiver,
        of what: String,
        stop: @escaping @Sendable () -> Void
            // swift-linter:disable:next untyped throws
            // REASON: the provider's next() and the receiver's append throw untyped; pump(_:into:of:stop:) types them.
    ) async throws {
        let (samples, taking) = (Wait.Held(provider), Wait.Held(receiver))
        while true {
            guard let buffer = try await Wait.sample("the next sample of \(what)", of: samples, stop: stop) else { break }
            try await Wait.answer("the writer to take a sample of \(what)", on: taking.reader) {
                try await taking.append(buffer)
            }
        }
        await taking.finish()
    }

    // swift-linter:disable:next untyped throws
    // REASON: it waits through Wait.answer, which throws untyped; write and score type it.
    /// Finishes a writer within the limit, and fails with `.writer` unless it completed.
    static func finish(_ writer: Wait.Held<AVAssetWriter>, _ name: String) async throws {
        let failure = try await Wait.answer("the writer to finish \(name)", on: writer.reader) {
            await writer.finish()
        }
        if let failure { throw Motion.Encoding.Error.writer(failure) }
    }

    /// What an `AVAssetReader` output's provider gives: its samples, ready.
    typealias Samples = AVAssetReaderOutput.Provider<CMReadySampleBuffer<CMSampleBuffer.DynamicContent>>

    /// The mixed sound as the reader gives it: interleaved 32-bit float stereo at 48 kHz.
    static var mixed: [String: any Sendable] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
    }

    /// The sound as the movie holds it: stereo AAC at 48 kHz, 192 kbit/s.
    static var aac: [String: any Sendable] {
        [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192_000]
    }
}

extension Motion.Encoding {
    /// A movie made smaller for sharing at a `Preset`: the largest picture of the movie's shape within the
    /// preset's size, never larger than the movie's own, at the bit rate `Motion.Encoding` writes by default,
    /// four bits per pixel per second, its picture encoded again and its frames and sound kept as
    /// `reduced(_:to:within:)` keeps them. A file already at `url` fails with `.writer`.
    public static func reduced(_ movie: URL, to url: URL, as preset: Preset) async throws(Motion.Encoding.Error) {
        let source = try await Inspection(of: movie)
        let size = preset.fit(width: source.width, height: source.height)
        try await reduced(movie, to: url, width: size.width, height: size.height, bits: bits(width: size.width, height: size.height))
    }

    /// The movie's picture encoded again as H.264 at `width` by `height` and `bits` per second, its frames
    /// and their durations, its timescale and its colour tag kept, and its sound, a track at most, copied
    /// sample for sample, written at `url`, where no file may be.
    static func reduced(_ movie: URL, to url: URL, width: Cardinal, height: Cardinal, bits: Cardinal) async throws(Motion.Encoding.Error) {
        guard width >= side, height >= side, let wide = Int(exactly: width), let tall = Int(exactly: height), let rate = Int(exactly: bits) else {
            throw .size(width: width, height: height, bits: bits)
        }
        // swift-linter:disable:next do throws for typed catch
        // REASON: AVAssetReader and AVAssetWriter throw untyped; their errors become Error.writer.
        do {
            try await reading { try await shrink(movie, to: url, width: wide, height: tall, bits: rate) }
        } catch let failure as Motion.Encoding.Error {
            throw failure
        } catch {
            throw .writer("\(error)")
        }
    }

    // swift-linter:disable:next untyped throws
    // REASON: loadTracks, AVAssetReader and AVAssetWriter throw untyped; reduced(_:to:width:height:bits:) types them.
    static func shrink(_ movie: URL, to url: URL, width: Int, height: Int, bits: Int) async throws {
        let asset = AVURLAsset(url: movie)
        let name = movie.lastPathComponent
        let stop: @Sendable () -> Void = { asset.cancelLoading() }
        let (frames, format, sounds, range, scale, hint) = try await Wait.load("the picture and sound of \(name)", stop: stop) {
            guard let frames = try await asset.loadTracks(withMediaType: .video).first, let format = try await frames.load(.formatDescriptions).first else {
                throw Motion.Encoding.Error.reader("\(name) has no picture")
            }
            let sounds = try await asset.loadTracks(withMediaType: .audio)
            guard sounds.count <= 1 else { throw Motion.Encoding.Error.reader("\(name) has more than one sound") }
            let hint = try await sounds.first?.load(.formatDescriptions).first
            return (frames, format, sounds, try await frames.load(.timeRange), try await frames.load(.naturalTimeScale), hint)
        }
        let reader = try AVAssetReader(asset: asset)
        let decoded = AVAssetReaderTrackOutput(track: frames, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        writer.movieTimeScale = scale
        var settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoScalingModeKey: AVVideoScalingModeResize,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bits,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        if let signal = Inspection.signal(format), let properties = Motion.Encoding(width: .zero, height: .zero, rate: .thirty, signal: signal).properties {
            settings[AVVideoColorPropertiesKey] = properties
        }
        let encoded = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        encoded.mediaTimeScale = scale
        if let sound = sounds.first {
            let copied = AVAssetReaderTrackOutput(track: sound, outputSettings: nil)
            let copy = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: hint)
            let (pictureProvider, pictureReceiver) = (reader.outputProvider(for: decoded), writer.inputReceiver(for: encoded))
            let (soundProvider, soundReceiver) = (reader.outputProvider(for: copied), writer.inputReceiver(for: copy))
            try reader.start()
            try writer.start()
            writer.startSession(atSourceTime: range.start)
            async let picturesEncoded: Void = pump(pictureProvider, into: pictureReceiver, of: "the picture of \(name)", stop: stop)
            async let soundCopied: Void = pump(soundProvider, into: soundReceiver, of: "the sound of \(name)", stop: stop)
            _ = try await (picturesEncoded, soundCopied)
        } else {
            let (pictureProvider, pictureReceiver) = (reader.outputProvider(for: decoded), writer.inputReceiver(for: encoded))
            try reader.start()
            try writer.start()
            writer.startSession(atSourceTime: range.start)
            try await pump(pictureProvider, into: pictureReceiver, of: "the picture of \(name)", stop: stop)
        }
        writer.endSession(atSourceTime: range.end)
        try await Self.finish(Wait.Held(writer), url.lastPathComponent)
    }
}

extension Motion.Encoding {
    /// The sizes `reduced(_:to:within:)` tries, largest first.
    static func ladder(width: Cardinal, height: Cardinal) -> [(width: Cardinal, height: Cardinal)] {
        let wide = Int(clamping: width)
        let tall = Int(clamping: height)
        let floor = Int(clamping: side)
        var sizes: [(Int, Int)] = []
        var (numerator, denominator) = (1, 1)
        while true {
            let size = (even(wide * numerator / denominator), even(tall * numerator / denominator))
            guard Swift.min(size.0, size.1) >= floor, numerator < Int.max / 3, denominator < Int.max / 4 else { break }
            if sizes.last.map({ $0 != size }) ?? true { sizes.append(size) }
            (numerator, denominator) = (numerator * 3, denominator * 4)
        }
        let smallest = wide <= tall ? (floor, Swift.max(floor, even(tall * floor / Swift.max(wide, 1)))) : (Swift.max(floor, even(wide * floor / Swift.max(tall, 1))), floor)
        if sizes.last.map({ $0 != smallest }) ?? true { sizes.append(smallest) }
        return sizes.map { (Cardinal(UInt($0.0)), Cardinal(UInt($0.1))) }
    }

    /// A count of pixels rounded down to an even number.
    static func even(_ pixels: Int) -> Int { pixels - pixels % 2 }

    /// The bytes a file's index is allowed besides the samples: 2 KiB and 16 bytes a frame.
    static func allowance(frames: Cardinal) -> Int { 2048 + 16 * Int(clamping: frames) }

    /// The bytes of a movie's sound samples, all tracks together.
    static func soundBytes(of url: URL) async throws(Motion.Encoding.Error) -> Cardinal {
        // swift-linter:disable:next do throws for typed catch
        // REASON: loadTracks and load throw untyped; their errors become Error.reader.
        do {
            let asset = AVURLAsset(url: url)
            let total = try await reading {
                try await Wait.load("the sound of \(url.lastPathComponent)", stop: { asset.cancelLoading() }) {
                    var total: Int64 = 0
                    for track in try await asset.loadTracks(withMediaType: .audio) {
                        total += try await track.load(.totalSampleDataLength)
                    }
                    return total
                }
            }
            return Cardinal(UInt(Swift.max(total, 0)))
        } catch let failure as Motion.Encoding.Error {
            throw failure
        } catch {
            throw .reader("\(error)")
        }
    }
}
