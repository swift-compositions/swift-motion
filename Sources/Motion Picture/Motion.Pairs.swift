#if Picture
    public import Motion
    public import Picture
    import Picture_CPU
    import Picture_PNG_Integration
    import Witnesses

    extension Motion {
        /// Sheets that set two films side by side at the same instants: each pair a frame of the reference on the
        /// left and the frame of the other film shown at the same instant on the right, labelled with the instant,
        /// and the pairs tiled `columns` to a row.
        ///
        /// Each frame is made `width` by `height` by `Raster.resampled` with the box filter, in linear light, so
        /// a frame of another shape is stretched to the tile. A frame that is missing, at an instant past a film's
        /// end, is a tile of `fill`. With a `label` each pair has a row above it of its own, the label's size and a
        /// quarter tall, where the instant is written in seconds with two decimals; without one there is no row.
        public struct Pairs: Sendable {
            /// A frame's width on the sheet.
            public var width: Cardinal

            /// A frame's height on the sheet.
            public var height: Cardinal

            /// How many pairs to a row.
            public var columns: Cardinal

            /// The space between the two frames of a pair, and between pairs.
            public var gap: Cardinal

            /// What lies under the tiles, the gaps and the labels.
            public var fill: Picture::Picture.Color

            /// How the instants are written, or nil for no labels.
            public var label: Label?

            public init(
                width: Cardinal,
                height: Cardinal,
                columns: Cardinal = 2,
                gap: Cardinal = 8,
                fill: Picture::Picture.Color = Picture::Picture.Color(gray: 0.12),
                label: Label? = nil
            ) {
                self.width = width
                self.height = height
                self.columns = columns
                self.gap = gap
                self.fill = fill
                self.label = label
            }
        }
    }

    extension Motion.Pairs {
        /// The instants `step` apart from zero, every one before `end`, in sheets of `count`: the last sheet holds
        /// what is left. A step that is not positive gives only zero, and no count is taken as one.
        public static func instants(every step: Rational, before end: Rational, count: Cardinal) -> [[Rational]] {
            guard end > .zero else { return [] }
            let all: [Rational] =
                step > .zero
                ? Swift.Array(Swift.sequence(first: Rational.zero) { $0 + step }.prefix { $0 < end })
                : [.zero]
            let size = Swift.max(Int(clamping: count), 1)
            return Swift.stride(from: 0, to: all.count, by: size).map { Swift.Array(all[$0..<Swift.min($0 + size, all.count)]) }
        }

        /// The sheet of these pairs, in their order, left to right and top to bottom.
        public func sheet(_ pairs: [Pair]) throws(Error) -> Raster<Picture::Picture.Pixel> {
            let tiles = try pairs.map { pair throws(Error) in try tile(pair) }
            do throws(Raster<Picture::Picture.Pixel>.Error) {
                return try Raster(tiling: tiles, columns: Swift.max(columns, 1), gap: gap, fill: fill.pixel)
            } catch {
                throw .sheet(error)
            }
        }

        /// The sheet of these pairs as PNG bytes, compressed fast.
        public func png(_ pairs: [Pair]) throws(Error) -> [Byte] {
            let sheet = try sheet(pairs)
            do throws(W3C_PNG::W3C_PNG.Image.Error) {
                return W3C_PNG::W3C_PNG.serialize(try W3C_PNG::W3C_PNG.Image(sheet), level: .fast)
            } catch {
                throw .png(error)
            }
        }

        /// One pair: its label's row, if any, over the two frames side by side.
        func tile(_ pair: Pair) throws(Error) -> Raster<Picture::Picture.Pixel> {
            let frames: Raster<Picture::Picture.Pixel>
            do throws(Raster<Picture::Picture.Pixel>.Error) {
                frames = try Raster(tiling: [frame(pair.reference), frame(pair.other)], columns: 2, gap: gap, fill: fill.pixel)
            } catch {
                throw .sheet(error)
            }
            guard let label else { return frames }
            var row = Raster<Picture::Picture.Pixel>(width: frames.width, height: label.height, repeating: fill.pixel)
            let written = try label.picture(of: pair.time)
            do throws(Picture::Picture.Renderer.Error) {
                try Witness.Context[Picture::Picture.Renderer.self].render(written, into: &row)
            } catch {
                throw .renderer(error)
            }
            do throws(Raster<Picture::Picture.Pixel>.Error) {
                return try Raster(tiling: [row, frames], columns: 1, fill: fill.pixel)
            } catch {
                throw .sheet(error)
            }
        }

        /// A frame made the tile's size in linear light, or a tile of the fill for no frame.
        func frame(_ raster: Raster<Motion.Pixel>?) -> Raster<Picture::Picture.Pixel> {
            guard let raster else { return Raster(width: width, height: height, repeating: fill.pixel) }
            let linear = raster.map { pixel in Picture::Picture.Color(pixel).pixel }
            return Motion.Hosting.Picture.Frames.shrunk(linear, width: width, height: height)
        }
    }
#endif
