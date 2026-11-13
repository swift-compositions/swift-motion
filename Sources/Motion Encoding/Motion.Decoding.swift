public import AVFoundation
public import Motion

extension Motion {
    /// A movie file read back as frames: the picture shown at exact instants or frame positions, as rasters.
    ///
    /// An instant is a time in seconds from the movie's start, and the frame shown there is the last one whose
    /// presentation starts at or before it, with no tolerance either way. A frame position is shown at its
    /// centre at the movie's rate. Frames are decoded by one `AVAssetReader` pass over the stretch asked for,
    /// from the sync frame before its start, and only the frames asked for become rasters.
    public struct Decoding: Sendable, Hashable {
        /// The movie read.
        public let url: URL

        /// The movie's codec, size, frames, length and rate, read from its file.
        public let inspection: Motion.Encoding.Inspection

        /// Reads the movie's inspection. A file that is no movie, or has no picture, fails with `.reader`.
        public init(_ url: URL) async throws(Motion.Encoding.Error) {
            self.url = url
            self.inspection = try await Motion.Encoding.Inspection(of: url)
        }
    }
}

extension Motion.Decoding {
    /// The frames shown at these instants, in the order given: nil for an instant before zero or at or after the
    /// end of the movie's last frame.
    public func frames(at instants: [Rational]) async throws(Motion.Encoding.Error) -> [Raster<Motion.Pixel>?] {
        let wanted = Array(Set(instants.filter { $0 >= .zero })).sorted()
        guard let first = wanted.first else { return instants.map { _ in nil } }
        // swift-linter:disable:next do throws for typed catch
        // REASON: AVURLAsset's loaders and AVAssetReader throw untyped; their errors become Error.reader.
        do {
            let shown = try await decode(wanted, from: first)
            return instants.map { shown[$0] }
        } catch let failure as Motion.Encoding.Error {
            throw failure
        } catch {
            throw .reader("\(error)")
        }
    }

    /// The frame shown at an instant, or nil before zero and from the end of the movie's last frame on.
    public func frame(at instant: Rational) async throws(Motion.Encoding.Error) -> Raster<Motion.Pixel>? {
        try await frames(at: [instant])[0]
    }

    /// The frames at these positions, in the order given, each the frame shown at its centre at the movie's rate.
    /// A position at or beyond the movie's frames fails with `.frame` before anything is decoded, and a movie that
    /// states no rate with `.reader`.
    public func frames(positions: [Ordinal]) async throws(Motion.Encoding.Error) -> [Raster<Motion.Pixel>] {
        guard let rate = inspection.rate else { throw .reader("\(url.lastPathComponent) states no frame duration") }
        if let beyond = positions.first(where: { $0 >= Ordinal(inspection.frames) }) { throw .frame(beyond) }
        let shown = try await frames(at: positions.map { rate.centre(of: Integer(Int(bitPattern: $0))) })
        return try zip(positions, shown).map { position, raster throws(Motion.Encoding.Error) in
            guard let raster else { throw .frame(position) }
            return raster
        }
    }

    /// The frame at a position: the frame shown at its centre at the movie's rate.
    public func frame(position: Ordinal) async throws(Motion.Encoding.Error) -> Raster<Motion.Pixel> {
        try await frames(positions: [position])[0]
    }

    // swift-linter:disable:next untyped throws
    // REASON: it calls AVURLAsset's loaders and AVAssetReader, which throw untyped; frames(at:) types them.
    /// The frames shown at instants given in ascending order, by instant, read in one pass from the sync frame
    /// before the first.
    func decode(_ wanted: [Rational], from first: Rational) async throws -> [Rational: Raster<Motion.Pixel>] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw Motion.Encoding.Error.reader("\(url.lastPathComponent) has no picture")
        }
        let scale = try await track.load(.naturalTimeScale)
        let limit = Motion.Encoding.instant(try await track.load(.timeRange).end)
        let reader = try AVAssetReader(asset: asset)
        let ticks = ((first * Rational(Integer(scale))).floor - Integer(scale)).exactly(CMTimeValue.self) ?? .max
        reader.timeRange = CMTimeRange(start: CMTime(value: Swift.max(ticks, 0), timescale: scale), duration: .positiveInfinity)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        var shown: [Rational: Raster<Motion.Pixel>] = [:]
        var next = wanted.startIndex
        var held: (start: Rational, end: Rational?, raster: Raster<Motion.Pixel>?)?
        while next < wanted.endIndex, let buffer = try await provider.next() {
            let timing = buffer.withUnsafeSampleBuffer { sample in (sample.presentationTimeStamp, sample.duration) }
            guard let begins = Motion.Encoding.instant(timing.0) else { continue }
            if let frame = held {
                while next < wanted.endIndex, wanted[next] < begins {
                    if wanted[next] >= frame.start { shown[wanted[next]] = frame.raster }
                    next += 1
                }
            }
            // WHY: a decoded frame may state no duration; the last one then lasts until the picture's end.
            let ends = Motion.Encoding.instant(timing.1).flatMap { $0 > .zero ? begins + $0 : nil } ?? limit
            // WHY: only a frame that can show at the next instant asked for becomes a raster.
            let needed = next < wanted.endIndex && ends.map { wanted[next] < $0 } ?? true
            held = (begins, ends, needed ? buffer.withUnsafeSampleBuffer { sample in sample.imageBuffer.flatMap(Motion.Encoding.raster) } : nil)
        }
        if let frame = held {
            for instant in wanted[next...] where instant >= frame.start && frame.end.map({ instant < $0 }) ?? false {
                shown[instant] = frame.raster
            }
        }
        reader.cancelReading()
        return shown
    }
}
