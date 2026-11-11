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
