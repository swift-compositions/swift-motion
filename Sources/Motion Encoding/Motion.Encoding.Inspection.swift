public import AVFoundation
public import Motion

extension Motion.Encoding {
    /// What a movie file holds, read back from the file itself.
    public struct Inspection: Hashable, Sendable {
        /// The picture's codec as its four-character code: `avc1` for H.264.
        public var codec: String
        public var width: Cardinal
        public var height: Cardinal
        /// The frames in the picture track, counted by stepping through every sample of its sample table.
        public var frames: Cardinal
        /// The movie's length in seconds, exactly as the file states it.
        public var duration: Rational
        /// The colour signal the picture is tagged with, or nil when it has no tag or one this package does not write.
        public var signal: ITU_T_H_273.Signal?
        /// The number of sound tracks.
        public var sounds: Cardinal
        /// The picture's rate: one over the shortest frame duration the file states, exactly; nil when it states none.
        /// For a movie whose frames all last the same, which is every movie `Motion.Encoding` writes, it is the frame rate.
        public var rate: Rate?

        /// Reads the movie at `url`. A file that is no movie, or has no picture, fails with `.reader`.
        public init(of url: URL) async throws(Motion.Encoding.Error) {
            // swift-linter:disable:next do throws for typed catch
            // REASON: AVURLAsset's loaders and AVAssetReader throw untyped; their errors become Error.reader.
            do {
                let asset = AVURLAsset(url: url)
                self = try await Motion.Encoding.Wait.load("what \(url.lastPathComponent) holds", stop: { asset.cancelLoading() }) {
                    try await Self(reading: asset, named: url.lastPathComponent)
                }
            } catch let failure as Motion.Encoding.Error {
                throw failure
            } catch {
                throw .reader("\(error)")
            }
        }

        // swift-linter:disable:next untyped throws
        // REASON: AVURLAsset's loaders throw untyped; init(of:) types them.
        /// What a movie holds, loaded from its asset; `name` names it in a failure.
        init(reading asset: AVURLAsset, named name: String) async throws {
            guard let track = try await asset.loadTracks(withMediaType: .video).first, let format = try await track.load(.formatDescriptions).first else {
                throw Motion.Encoding.Error.reader("\(name) has no picture")
            }
            let size = format.dimensions
            let length = try await asset.load(.duration)
            guard let width = UInt(exactly: size.width), let height = UInt(exactly: size.height), length.timescale > 0 else {
                throw Motion.Encoding.Error.reader("\(name) states no size or length")
            }
            guard try await track.load(.canProvideSampleCursors) else {
                throw Motion.Encoding.Error.reader("\(name) has a picture whose samples cannot be stepped through")
            }
            // WHY: The count walks the track's sample table and reads no sample data. An AVAssetReader
            // waits on CoreMedia's shared read queue, and three movies read at once have waited there for good.
            var frames = Cardinal.zero
            if let cursor = track.makeSampleCursorAtFirstSampleInDecodeOrder() {
                frames += Cardinal.one
                while cursor.stepInDecodeOrder(byCount: 1) == 1 { frames += Cardinal.one }
            }
            let shortest = try await track.load(.minFrameDuration)
            let code = format.mediaSubType.rawValue
            self.init(
                codec: String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }, as: UTF8.self),
                width: Cardinal(width),
                height: Cardinal(height),
                frames: frames,
                duration: try Rational(numerator: Integer(length.value), denominator: Integer(length.timescale)),
                signal: Self.signal(format),
                sounds: Cardinal(UInt(try await asset.loadTracks(withMediaType: .audio).count)),
                rate: Self.rate(shortest)
            )
        }

        init(
            codec: String,
            width: Cardinal,
            height: Cardinal,
            frames: Cardinal,
            duration: Rational,
            signal: ITU_T_H_273.Signal?,
            sounds: Cardinal,
            rate: Rate?
        ) {
            self.codec = codec
            self.width = width
            self.height = height
            self.frames = frames
            self.duration = duration
            self.signal = signal
            self.sounds = sounds
            self.rate = rate
        }
    }
}

extension Motion.Encoding.Inspection {
    /// One over a frame's duration, exactly; nil for a duration that is not a positive time.
    static func rate(_ duration: CMTime) -> Rate? {
        guard duration.isNumeric, duration.value > 0, duration.timescale > 0 else { return nil }
        do throws(Rate.Error) {
            return try Rate(Integer(duration.timescale), per: Integer(duration.value))
        } catch {
            return nil
        }
    }

    /// The H.273 signal a format description's colour tags name, where this package writes that tag.
    static func signal(_ format: CMFormatDescription) -> ITU_T_H_273.Signal? {
        let tags = CMFormatDescriptionGetExtensions(format) as? [String: Any] ?? [:]
        let primaries: ITU_T_H_273.Primaries? =
            switch tags[kCMFormatDescriptionExtension_ColorPrimaries as String] as? String {
            case AVVideoColorPrimaries_ITU_R_709_2: .bt709
            case AVVideoColorPrimaries_ITU_R_2020: .bt2020
            case AVVideoColorPrimaries_P3_D65: .displayP3
            default: nil
            }
        let transfer: ITU_T_H_273.Transfer? =
            switch tags[kCMFormatDescriptionExtension_TransferFunction as String] as? String {
            case AVVideoTransferFunction_ITU_R_709_2: .bt709
            case AVVideoTransferFunction_IEC_sRGB: .sRGB
            case AVVideoTransferFunction_SMPTE_ST_2084_PQ: .pq
            case AVVideoTransferFunction_ITU_R_2100_HLG: .hlg
            case AVVideoTransferFunction_Linear: .linear
            default: nil
            }
        let matrix: ITU_T_H_273.Matrix? =
            switch tags[kCMFormatDescriptionExtension_YCbCrMatrix as String] as? String {
            case AVVideoYCbCrMatrix_ITU_R_709_2: .bt709
            case AVVideoYCbCrMatrix_ITU_R_601_4: .bt601
            case AVVideoYCbCrMatrix_ITU_R_2020: .bt2020
            default: nil
            }
        guard let primaries, let transfer, let matrix else { return nil }
        let full = tags[kCMFormatDescriptionExtension_FullRangeVideo as String] as? Bool ?? false
        return ITU_T_H_273.Signal(primaries: primaries, transfer: transfer, matrix: matrix, range: full ? .full : .limited)
    }
}
