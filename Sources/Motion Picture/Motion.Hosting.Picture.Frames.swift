public import Motion
public import Picture
import Picture_CPU
import Synchronization
import Thread_Pool

extension Motion.Hosting.Picture {
    /// The frames of a motion as pictures, drawn several at a time: each on a thread of its own, with one
    /// thread inside the frame, so that as many frames are in work as there are workers and no thread
    /// waits for another.
    ///
    /// `picture` gives the picture at a position, and is called on the thread that draws it. Every frame is
    /// drawn through the one `renderer`, so a part of the picture that it keeps (an image that names its
    /// picture) is drawn once for all the frames that show it.
    public struct Frames: Sendable {
        public var width: Cardinal
        public var height: Cardinal
        public var background: Picture::Picture.Color
        public var renderer: Picture::Picture.Renderer
        public var picture: @Sendable (Ordinal) -> Picture::Picture

        /// How many frames are drawn at once.
        public let workers: Cardinal

        let pool: Kernel.Thread.Pool

        /// Without a number of workers there are as many as the machine has logical processors, and none
        /// counts as one. Without a renderer it is `Picture.Renderer.cpu(threads: 1)`.
        public init(
            width: Cardinal,
            height: Cardinal,
            over background: Picture::Picture.Color = .black,
            workers: Cardinal? = nil,
            renderer: Picture::Picture.Renderer? = nil,
            picture: @escaping @Sendable (Ordinal) -> Picture::Picture
        ) {
            let count = Swift.max(workers ?? Cardinal(UInt(Int(CPU.Logical.count))), 1)
            self.width = width
            self.height = height
            self.background = background
            self.renderer = renderer ?? .cpu(threads: 1)
            self.picture = picture
            self.workers = count
            self.pool = Kernel.Thread.Pool(.init(workers: Kernel.Thread.Count(Int(clamping: count))))
        }
    }
}

extension Motion.Hosting.Picture.Frames {
    /// The frames at some positions, each drawn at `width` by `height` over the background and handed to
    /// `frame` on the thread that drew it, and what `frame` made of them in the order of the positions.
    ///
    /// The workers take the positions one at a time, so a frame that is dear holds up no other. A frame is
    /// the one `Motion.Hosting.Picture.raster(_:width:height:over:)` draws through the same renderer, before
    /// it is turned into the movie's pixels. The first frame that fails stops the rest from being started,
    /// and its failure is thrown with its position.
    public func drawn<Frame: Sendable>(
        _ positions: [Ordinal],
        as frame: @escaping @Sendable (_ position: Ordinal, _ raster: Raster<Picture::Picture.Pixel>) -> Frame
    ) async throws(Error) -> [Frame] {
        guard !positions.isEmpty else { return [] }
        let progress = Progress<Frame>(count: positions.count)
        let work: @Sendable () -> Void = {
            while true {
                let place = progress.next.wrappingAdd(1, ordering: .relaxed).oldValue
                guard place < positions.count, progress.results.withLock({ $0.failure == nil }) else { return }
                var raster = Raster<Picture::Picture.Pixel>(width: width, height: height, repeating: background.pixel)
                do throws(Picture::Picture.Renderer.Error) {
                    try renderer.render(picture(positions[place]), into: &raster)
                } catch {
                    progress.results.withLock { if $0.failure == nil { $0.failure = .renderer(error, at: positions[place]) } }
                    return
                }
                let made = frame(positions[place], raster)
                progress.results.withLock { $0.frames[place] = made }
            }
        }
        let threads = Swift.min(Int(clamping: workers), positions.count)
        let refused = await withTaskGroup(of: Kernel.Thread.Pool.Error?.self) { group in
            for _ in 0..<threads {
                group.addTask {
                    do throws(Kernel.Thread.Pool.Error) {
                        try await self.pool.run(work)
                        return nil
                    } catch {
                        return error
                    }
                }
            }
            var refused: Kernel.Thread.Pool.Error?
            for await failure in group { refused = refused ?? failure }
            return refused
        }
        let (frames, failure) = progress.results.withLock { ($0.frames, $0.failure) }
        if let failure { throw failure }
        if let refused { throw .pool(refused) }
        return frames.compactMap { $0 }
    }

    /// The frames at some positions as a movie's frames, in the order of the positions.
    public func rasters(_ positions: [Ordinal]) async throws(Error) -> [Raster<Motion.Pixel>] {
        try await drawn(positions) { _, raster in raster.map { pixel in Motion.Pixel(pixel) } }
    }

    /// A contact sheet: the frames at some positions, each made `columns` times as small along each side by
    /// `Raster.resampled` with the box filter, and laid out `columns` to a row with a gap between them by
    /// `Raster(tiling:columns:gap:fill:)`.
    public func sheet(
        _ positions: [Ordinal],
        columns: Cardinal,
        gap: Cardinal = .zero,
        fill: Picture::Picture.Color = .black
    ) async throws(Error) -> Raster<Picture::Picture.Pixel> {
        let across = Swift.max(columns, 1)
        let (small, short) = (Cardinal(UInt(Int(clamping: width) / Int(clamping: across))), Cardinal(UInt(Int(clamping: height) / Int(clamping: across))))
        let tiles = try await drawn(positions) { _, raster in
            raster.resampled(width: small, height: short, .box) { (from: Picture::Picture.Pixel, to: Picture::Picture.Pixel, parameter: Float) in
                from.interpolated(to: to, at: parameter)
            }
        }
        do throws(Raster<Picture::Picture.Pixel>.Error) {
            return try Raster(tiling: tiles, columns: across, gap: gap, fill: fill.pixel)
        } catch {
            throw .sheet(error)
        }
    }

    /// The first `count` frames, to be asked for one after another: a `Feed` that draws them a stretch at a
    /// time, `ahead` frames to a stretch, and holds one stretch. Without `ahead` a stretch is four frames for
    /// each worker.
    public func feed<Frame: Sendable>(
        first count: Cardinal,
        ahead: Cardinal? = nil,
        as frame: @escaping @Sendable (_ position: Ordinal, _ raster: Raster<Picture::Picture.Pixel>) -> Frame
    ) -> Feed<Frame> {
        Feed(self, count: count, ahead: Swift.max(ahead ?? Cardinal(UInt(4 * Int(clamping: workers))), 1), frame)
    }

    /// The first `count` frames as a movie's frames, to be asked for one after another, which is how
    /// `Motion.Encoding.write(frames:to:raster:)` asks.
    public func feed(first count: Cardinal, ahead: Cardinal? = nil) -> Feed<Raster<Motion.Pixel>> {
        feed(first: count, ahead: ahead) { _, raster in raster.map { pixel in Motion.Pixel(pixel) } }
    }
}
