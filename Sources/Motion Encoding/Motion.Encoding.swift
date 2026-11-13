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

    /// The width, height and bit rate as AVFoundation takes them.
    func sizes() throws(Motion.Encoding.Error) -> (width: Int, height: Int, bits: Int) {
        guard let wide = Int(exactly: width), let tall = Int(exactly: height), let bits = Int(exactly: bitRate) else {
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
            try await encode(frames: count, to: url, properties: properties, raster: raster)
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
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        var index = Ordinal.zero
        while index < Ordinal(count) {
            guard let frame = await raster(index), frame.width == width, frame.height == height else { throw Motion.Encoding.Error.frame(index) }
            var buffer = if let pool = receiver.pixelBufferPool { try pool.makeMutablePixelBuffer() } else { try CVMutablePixelBuffer(attributes) }
            Self.copy(frame, into: &buffer)
            try await receiver.append(CVReadOnlyPixelBuffer(buffer), with: try time(of: index))
            index += Cardinal.one
        }
        receiver.finish()
        writer.endSession(atSourceTime: try end(of: count))
        await writer.finishWriting()
        guard writer.status == .completed else { throw Motion.Encoding.Error.writer(writer.error?.localizedDescription ?? "not completed") }
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

    static func copy(_ raster: Raster<Motion.Pixel>, into buffer: inout CVMutablePixelBuffer) {
        unsafe buffer.accessUnsafeMutableRawPlaneBytes { planes in
            guard let plane = unsafe planes.first else { return }
            guard let columns = Int(exactly: raster.width), let rows = Int(exactly: raster.height) else { return }
            let row = columns * 4
            let stride = unsafe plane.properties.bytesPerRow
            raster.bytes.withUnsafeBytes { source in
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
            try await join(silent, sound, to: url)
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
        let composition = AVMutableComposition()
        let duration = try await picture.load(.duration)
        guard
            let frames = try await picture.loadTracks(withMediaType: .video).first,
            let samples = try await audio.loadTracks(withMediaType: .audio).first,
            let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let sound = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw Motion.Encoding.Error.writer("\(silent.lastPathComponent) or \(sound.lastPathComponent) has no track") }
        video.naturalTimeScale = try await frames.load(.naturalTimeScale)
        try video.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: frames, at: .zero)
        let length = min(duration, try await audio.load(.duration))
        try sound.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: samples, at: .zero)
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw Motion.Encoding.Error.writer("no passthrough export session")
        }
        session.shouldOptimizeForNetworkUse = true
        try await session.export(to: url, as: .mp4)
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
            let asset = AVURLAsset(url: url)
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw Motion.Encoding.Error.reader("\(url.lastPathComponent) has no picture")
            }
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            let provider = reader.outputProvider(for: output)
            try reader.start()
            var frame = Ordinal.zero
            while let buffer = try await provider.next() {
                guard let raster = buffer.withUnsafeSampleBuffer({ sample in sample.imageBuffer.flatMap(Self.raster) }) else { continue }
                await each(frame, raster)
                frame += Cardinal.one
            }
            guard reader.status == .completed else { throw Motion.Encoding.Error.reader(reader.error?.localizedDescription ?? "not read to the end") }
            return Cardinal(frame)
        } catch let failure as Motion.Encoding.Error {
            throw failure
        } catch {
            throw .reader("\(error)")
        }
    }

    /// The pixels of a decoded BGRA frame.
    static func raster(_ buffer: CVPixelBuffer) -> Raster<Motion.Pixel>? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = unsafe CVPixelBufferGetBaseAddress(buffer),
            let width = UInt(exactly: CVPixelBufferGetWidth(buffer)),
            let height = UInt(exactly: CVPixelBufferGetHeight(buffer)),
            let stride = UInt(exactly: CVPixelBufferGetBytesPerRow(buffer))
        else { return nil }
        let bytes = unsafe [UInt8](UnsafeRawBufferPointer(start: base, count: CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer)))
        do throws(Motion.Pixel.Error) {
            return try Raster<Motion.Pixel>(width: Cardinal(width), height: Cardinal(height), stride: Cardinal(stride), bytes: bytes)
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
            try await lay(cues, under: picture, to: url)
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
        guard let frames = try await movie.loadTracks(withMediaType: .video).first, let format = try await frames.load(.formatDescriptions).first else {
            throw Motion.Encoding.Error.reader("\(picture.lastPathComponent) has no picture")
        }
        let range = try await frames.load(.timeRange)
        guard let film = instant(range.end) else { throw Motion.Encoding.Error.reader("\(picture.lastPathComponent) states no length") }
        let scale = try await frames.load(.naturalTimeScale)
        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Motion.Encoding.Error.writer("no picture track could be made")
        }
        video.naturalTimeScale = scale
        try video.insertTimeRange(CMTimeRange(start: .zero, duration: range.end), of: frames, at: .zero)
        var parameters: [AVMutableAudioMixInputParameters] = []
        for (index, cue) in cues.enumerated() {
            let sound = AVURLAsset(url: cue.sound)
            guard let samples = try await sound.loadTracks(withMediaType: .audio).first, let heard = instant(try await sound.load(.duration)) else {
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
        let sounds = AVAssetReaderAudioMixOutput(audioTracks: composition.tracks(withMediaType: .audio), audioSettings: Self.mixed)
        sounds.audioMix = mix
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        writer.movieTimeScale = scale
        let copied = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: format)
        copied.mediaTimeScale = scale
        let encoded = AVAssetWriterInput(mediaType: .audio, outputSettings: Self.aac)
        let (pictureProvider, soundProvider) = (reader.outputProvider(for: pictures), reader.outputProvider(for: sounds))
        let (pictureReceiver, soundReceiver) = (writer.inputReceiver(for: copied), writer.inputReceiver(for: encoded))
        try reader.start()
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        async let picturesCopied: Void = pump(pictureProvider, into: pictureReceiver)
        async let soundsEncoded: Void = pump(soundProvider, into: soundReceiver)
        _ = try await (picturesCopied, soundsEncoded)
        writer.endSession(atSourceTime: range.end)
        await writer.finishWriting()
        guard writer.status == .completed else { throw Motion.Encoding.Error.writer(writer.error?.localizedDescription ?? "not completed") }
    }

    /// A cue's level over its stretch: its gain, reached from silence over its fade in and left for silence
    /// over its fade out, two fades longer together than the stretch each cut to half of it.
    static func levels(of cue: Cue, lasting length: Rational, on track: AVCompositionTrack) throws(Motion.Encoding.Error) -> AVMutableAudioMixInputParameters {
        let half: Rational
        do throws(Rational.Error) {
            half = try Rational(numerator: length.numerator, denominator: length.denominator * 2)
        } catch {
            preconditionFailure("a positive length halves")
        }
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
    /// A failure to read or to append is `.writer`.
    static func pump(
        _ provider: sending AVAssetReaderOutput.Provider<CMReadySampleBuffer<CMSampleBuffer.DynamicContent>>,
        into receiver: sending AVAssetWriterInput.SampleBufferReceiver
    ) async throws(Motion.Encoding.Error) {
        // swift-linter:disable:next do throws for typed catch
        // REASON: the provider's next() and the receiver's append throw untyped; their errors become Error.writer.
        do {
            while let buffer = try await provider.next() {
                try await receiver.append(buffer)
            }
        } catch {
            throw .writer("\(error)")
        }
        receiver.finish()
    }

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
    /// A movie made smaller for sharing, at one of AVFoundation's export presets: H.264 within the preset's
    /// size, the picture's shape kept and never made larger, and its sound as AAC. A file already at `url`
    /// fails the export with `.writer`.
    public static func reduced(_ movie: URL, to url: URL, as preset: Preset) async throws(Motion.Encoding.Error) {
        // swift-linter:disable:next do throws for typed catch
        // REASON: AVAssetExportSession throws untyped; its errors become Error.writer.
        do {
            guard let session = AVAssetExportSession(asset: AVURLAsset(url: movie), presetName: preset.name) else {
                throw Motion.Encoding.Error.writer("no export session for \(preset)")
            }
            session.shouldOptimizeForNetworkUse = true
            try await session.export(to: url, as: .mp4)
        } catch let failure as Motion.Encoding.Error {
            throw failure
        } catch {
            throw .writer("\(error)")
        }
    }
}
