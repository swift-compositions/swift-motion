#if Picture
    public import Byte
    import Binary
    public import Motion
    public import Picture
    public import Picture_PNG_Integration
    import RFC_1951

    extension Motion.Hosting.Picture.Frames {
        /// What is made of each drawn raster, and how it is kept in a store: by a name that says what it is, which
        /// becomes part of the key, as bytes, and back from them. A form without a name, or a frame it gives no
        /// bytes for, is never kept; bytes it cannot read back are a miss and the frame is drawn.
        ///
        /// What a form reads back must be what `make` makes, value for value, so that a frame read from a store is
        /// the frame drawing gives.
        public struct Form<Frame: Sendable>: Sendable {
            public let name: (@Sendable (_ position: Ordinal) -> Swift.String)?
            public let make: @Sendable (_ position: Ordinal, _ raster: Raster<Picture::Picture.Pixel>) -> Frame
            public let bytes: @Sendable (Frame) -> [Byte]?
            public let frame: @Sendable ([Byte]) -> Frame?

            public init(
                name: (@Sendable (_ position: Ordinal) -> Swift.String)?,
                make: @escaping @Sendable (_ position: Ordinal, _ raster: Raster<Picture::Picture.Pixel>) -> Frame,
                bytes: @escaping @Sendable (Frame) -> [Byte]?,
                frame: @escaping @Sendable ([Byte]) -> Frame?
            ) {
                self.name = name
                self.make = make
                self.bytes = bytes
                self.frame = frame
            }

            /// A form that is never kept.
            public init(_ make: @escaping @Sendable (_ position: Ordinal, _ raster: Raster<Picture::Picture.Pixel>) -> Frame) {
                self.init(name: nil, make: make, bytes: { _ in nil }, frame: { _ in nil })
            }
        }
    }

    extension Motion.Hosting.Picture.Frames.Form where Frame == Raster<Motion.Pixel> {
        /// The movie's frame, kept as its width, its height and its pixels' bytes: four a pixel.
        ///
        /// Kept, the pixels' memory is copied once, behind the width and the height. Read back, it is copied once
        /// into the frame's pixels, and every pixel is checked to be premultiplied on the way, as for bytes from
        /// anywhere: the store's Adler-32 finds damage by chance, not for certain, and an entry is a file anyone
        /// can write, so its bytes are not known to be what this form wrote.
        public static var movie: Self {
            Self(
                name: { _ in "Motion.Pixel" },
                make: { _, raster in raster.map { pixel in Motion.Pixel(pixel) } },
                bytes: { raster in Motion.Hosting.Picture.Frames.kept(raster) },
                frame: { bytes in Motion.Hosting.Picture.Frames.movie(bytes) }
            )
        }

        /// The movie's frame as `movie` keeps it, compressed by DEFLATE (RFC 1951) at its fast level, and read back
        /// as `movie` reads it once inflated: the same frame, value for value, in about a sixth of the bytes of a
        /// film's frame, for about 30 ms more when kept and some milliseconds more when read.
        /// Bytes that do not inflate are a miss.
        public static var deflated: Self {
            Self(
                name: { _ in "Motion.Pixel deflate fast" },
                make: { _, raster in raster.map { pixel in Motion.Pixel(pixel) } },
                bytes: { raster in RFC_1951.compress(Motion.Hosting.Picture.Frames.kept(raster), level: .fast) },
                frame: { bytes in
                    do throws(RFC_1951.Error) {
                        let inflated = try RFC_1951.decompress(bytes)
                        return Motion.Hosting.Picture.Frames.movie(inflated)
                    } catch {
                        return nil
                    }
                }
            )
        }
    }

    extension Motion.Hosting.Picture.Frames.Form where Frame == Raster<Picture::Picture.Pixel> {
        /// The drawn raster itself, made `width` by `height` by `transform`, kept as its working pixels' memory:
        /// sixteen bytes a pixel, so meant for small rasters, such as a sheet's tiles.
        public static func working(
            _ name: Swift.String,
            _ transform: @escaping @Sendable (Raster<Picture::Picture.Pixel>) -> Raster<Picture::Picture.Pixel>
        ) -> Self {
            Self(
                name: { _ in name },
                make: { _, raster in transform(raster) },
                bytes: { raster in Motion.Hosting.Picture.Frames.working(raster) },
                frame: { bytes in Motion.Hosting.Picture.Frames.working(bytes, from: 0)?.raster }
            )
        }
    }

    extension Motion.Hosting.Picture.Frames.Form where Frame == Result<[Byte], W3C_PNG::W3C_PNG.Image.Error> {
        /// The frame as PNG bytes, compressed fast, kept as they are; a frame PNG refuses is not kept.
        public static var png: Self {
            Self(
                name: { _ in "PNG fast" },
                make: { _, raster in Result { () throws(W3C_PNG::W3C_PNG.Image.Error) in try Motion.Hosting.Picture.Frames.png(raster) } },
                bytes: { made in if case .success(let bytes) = made { bytes } else { nil } },
                frame: { bytes in .success(bytes) }
            )
        }
    }

    extension Motion.Hosting.Picture.Frames {
        /// A raster of the picture's pixels as PNG bytes, compressed fast.
        static func png(_ raster: Raster<Picture::Picture.Pixel>) throws(W3C_PNG::W3C_PNG.Image.Error) -> [Byte] {
            W3C_PNG::W3C_PNG.serialize(try W3C_PNG::W3C_PNG.Image(raster), level: .fast)
        }

        /// The eight bytes at an offset as an unsigned integer, little-endian, or the largest where they are not
        /// all there.
        static func number(_ bytes: [Byte], at offset: Int) -> UInt64 {
            guard offset >= 0, offset <= bytes.count - 8 else { return .max }
            return UInt64(bytes: bytes[offset..<(offset + 8)], endianness: .little) ?? .max
        }

        /// A raster as its width and its height, eight bytes each, little-endian, and its pixels' memory, copied
        /// once.
        static func kept<Pixel>(_ raster: Raster<Pixel>) -> [Byte] {
            var head: [Byte] = []
            UInt64(Int(clamping: raster.width)).bytes(into: &head, endianness: .little)
            UInt64(Int(clamping: raster.height)).bytes(into: &head, endianness: .little)
            return raster.pixels.withUnsafeBytes { memory in
                unsafe [Byte](unsafeUninitializedCapacity: head.count + memory.count) { target, count in
                    let into = UnsafeMutableRawBufferPointer(target)
                    head.withUnsafeBytes { unsafe into.copyMemory(from: $0) }
                    unsafe UnsafeMutableRawBufferPointer(rebasing: into[head.count...]).copyMemory(from: memory)
                    count = head.count + memory.count
                }
            }
        }

        /// A movie's frame `kept(_:)` wrote, or nil when the bytes are not one.
        static func movie(_ bytes: [Byte]) -> Raster<Motion.Pixel>? {
            guard bytes.count >= 16, let columns = UInt(exactly: number(bytes, at: 0)), let rows = UInt(exactly: number(bytes, at: 8)) else { return nil }
            do throws(Motion.Pixel.Error) {
                return try unsafe Raster(width: Cardinal(columns), height: Cardinal(rows), bytes: bytes.span.bytes.extracting(droppingFirst: 16))
            } catch {
                return nil
            }
        }

        /// A raster of working pixels as its width, its height and its pixels' memory.
        static func working(_ raster: Raster<Picture::Picture.Pixel>) -> [Byte] {
            kept(raster)
        }

        /// A raster of working pixels written by `working(_:)` at an offset, and the offset after it, or nil.
        static func working(_ bytes: [Byte], from offset: Int) -> (raster: Raster<Picture::Picture.Pixel>, end: Int)? {
            let width = number(bytes, at: offset)
            let height = number(bytes, at: offset + 8)
            let stride = MemoryLayout<Picture::Picture.Pixel>.stride
            let (count, overflow) = width.multipliedReportingOverflow(by: height)
            guard !overflow, count <= UInt64(Int.max / stride / 2) else { return nil }
            let start = offset + 16
            let end = start + Int(count) * stride
            guard end <= bytes.count else { return nil }
            let pixels = bytes.withUnsafeBytes { source in
                unsafe [Picture::Picture.Pixel](unsafeUninitializedCapacity: Int(count)) { target, initialized in
                    unsafe UnsafeMutableRawBufferPointer(target).copyMemory(from: UnsafeRawBufferPointer(rebasing: source[start..<end]))
                    initialized = Int(count)
                }
            }
            do throws(Raster<Picture::Picture.Pixel>.Error) {
                return (try Raster(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), pixels: pixels), end)
            } catch {
                return nil
            }
        }
    }
#endif
