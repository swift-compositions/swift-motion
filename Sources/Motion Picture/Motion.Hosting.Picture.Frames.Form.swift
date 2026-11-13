#if Picture
    public import Byte
    public import Motion
    public import Picture
    public import Picture_PNG_Integration

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
        public static var movie: Self {
            Self(
                name: { _ in "Motion.Pixel" },
                make: { _, raster in raster.map { pixel in Motion.Pixel(pixel) } },
                bytes: { raster in
                    var head: [UInt8] = []
                    Motion.Hosting.Picture.Frames.number(UInt64(Int(clamping: raster.width)), into: &head)
                    Motion.Hosting.Picture.Frames.number(UInt64(Int(clamping: raster.height)), into: &head)
                    return Motion.Hosting.Picture.Frames.bytes(head + raster.bytes)
                },
                frame: { bytes in
                    guard bytes.count >= 16 else { return nil }
                    let width = Motion.Hosting.Picture.Frames.number(bytes, at: 0)
                    let height = Motion.Hosting.Picture.Frames.number(bytes, at: 8)
                    let raw = Motion.Hosting.Picture.Frames.raw(bytes, from: 16)
                    return try? Raster(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), bytes: raw)
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
                bytes: { made in try? made.get() },
                frame: { bytes in .success(bytes) }
            )
        }
    }

    extension Motion.Hosting.Picture.Frames {
        /// A raster of the picture's pixels as PNG bytes, compressed fast.
        static func png(_ raster: Raster<Picture::Picture.Pixel>) throws(W3C_PNG::W3C_PNG.Image.Error) -> [Byte] {
            W3C_PNG::W3C_PNG.serialize(try W3C_PNG::W3C_PNG.Image(raster), level: .fast)
        }

        static func number(_ value: UInt64, into bytes: inout [UInt8]) {
            withUnsafeBytes(of: value.littleEndian) { unsafe bytes.append(contentsOf: $0) }
        }

        static func number(_ bytes: [Byte], at offset: Int) -> UInt64 {
            guard offset + 8 <= bytes.count else { return .max }
            var value: UInt64 = 0
            for index in (0..<8).reversed() {
                value = value << 8 | UInt64(bytes[offset + index].bitPattern)
            }
            return value
        }

        /// Bytes as `Byte`s, copied in one piece.
        static func bytes(_ raw: [UInt8]) -> [Byte] {
            raw.withUnsafeBytes { source in
                unsafe [Byte](unsafeUninitializedCapacity: source.count) { target, count in
                    unsafe UnsafeMutableRawBufferPointer(target).copyMemory(from: source)
                    count = source.count
                }
            }
        }

        /// `Byte`s from an offset on as bytes, copied in one piece.
        static func raw(_ bytes: [Byte], from offset: Int) -> [UInt8] {
            guard offset <= bytes.count else { return [] }
            return bytes.withUnsafeBytes { source in
                let tail = unsafe UnsafeRawBufferPointer(rebasing: source[offset...])
                return unsafe [UInt8](unsafeUninitializedCapacity: tail.count) { target, count in
                    unsafe UnsafeMutableRawBufferPointer(target).copyMemory(from: tail)
                    count = tail.count
                }
            }
        }

        /// A raster of working pixels as its width, its height and its pixels' memory.
        static func working(_ raster: Raster<Picture::Picture.Pixel>) -> [Byte] {
            var head: [UInt8] = []
            number(UInt64(Int(clamping: raster.width)), into: &head)
            number(UInt64(Int(clamping: raster.height)), into: &head)
            let pixels = raster.pixels.withUnsafeBytes { unsafe [UInt8]($0) }
            return bytes(head + pixels)
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
            guard let raster = try? Raster(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), pixels: pixels) else { return nil }
            return (raster, end)
        }
    }
#endif
