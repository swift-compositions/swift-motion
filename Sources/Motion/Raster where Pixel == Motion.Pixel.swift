import Numeric
public import Raster

/// A frame's picture is a `Raster<Motion.Pixel>`: BGRA8 pixels, premultiplied, in sRGB, stored packed.
extension Raster where Pixel == Motion.Pixel {
    /// Reads `height` rows of `width` pixels from bytes in blue, green, red, alpha order, rows `stride` bytes apart.
    /// Row padding is dropped. Without a `stride` the rows are packed, `width × 4` bytes apart.
    public init(width: Cardinal, height: Cardinal, stride: Cardinal? = nil, bytes: [UInt8]) throws(Motion.Pixel.Error) {
        self = try bytes.span.bytes.withUnsafeBytes { source throws(Motion.Pixel.Error) in
            try unsafe Self.read(width: width, height: height, stride: stride, source)
        }
    }

    /// `init(width:height:stride:bytes:)` of bytes in memory, such as a pixel buffer's or a stored entry's: every
    /// pixel is checked, then the rows are copied out once, in one piece when they are packed.
    public init(width: Cardinal, height: Cardinal, stride: Cardinal? = nil, bytes: borrowing RawSpan) throws(Motion.Pixel.Error) {
        self = try bytes.withUnsafeBytes { source throws(Motion.Pixel.Error) in
            try unsafe Self.read(width: width, height: height, stride: stride, source)
        }
    }

    /// The raster both initializers read: the sizes checked against the bytes, then the pixels.
    static func read(width: Cardinal, height: Cardinal, stride: Cardinal?, _ source: UnsafeRawBufferPointer) throws(Motion.Pixel.Error) -> Self {
        guard let columns = Int(exactly: width), let rows = Int(exactly: height) else { throw .overflow }
        let (row, wide) = columns.multipliedReportingOverflow(by: 4)
        guard !wide else { throw .overflow }
        guard let step = stride.map({ Int(exactly: $0) }) ?? row else { throw .overflow }
        guard step >= row else { throw .stride(Cardinal(UInt(step)), needed: Cardinal(UInt(row))) }
        let (needed, long) = step.multipliedReportingOverflow(by: rows)
        guard !long else { throw .overflow }
        guard source.count == needed else { throw .size(Cardinal(UInt(source.count)), needed: Cardinal(UInt(needed))) }
        let pixels = try unsafe Self.pixels(columns: columns, rows: rows, step: step, source)
        do throws(Raster<Motion.Pixel>.Error) {
            return try Self(width: width, height: height, pixels: pixels)
        } catch {
            throw .overflow
        }
    }

    /// The pixels of `rows` rows of `columns` pixels, rows `step` bytes apart; the sizes are already checked.
    /// A pixel is its four bytes in the order they are read, so the rows are checked and then copied whole.
    /// Rows of no pixels hold nothing to read, however many bytes lie between them.
    static func pixels(columns: Int, rows: Int, step: Int, _ source: UnsafeRawBufferPointer) throws(Motion.Pixel.Error) -> [Motion.Pixel] {
        guard columns > 0 else { return [] }
        if let fault = unsafe fault(columns: columns, rows: rows, step: step, source) {
            throw .premultiplied(x: Ordinal(UInt(fault.x)), y: Ordinal(UInt(fault.y)))
        }
        let row = columns * 4
        return unsafe [Motion.Pixel](unsafeUninitializedCapacity: columns * rows) { pixels, count in
            let target = UnsafeMutableRawBufferPointer(pixels)
            if step == row {
                unsafe target.copyMemory(from: UnsafeRawBufferPointer(rebasing: source[0..<(row * rows)]))
            } else {
                var y = 0
                while y < rows {
                    let from = unsafe UnsafeRawBufferPointer(rebasing: source[(y * step)..<(y * step + row)])
                    unsafe UnsafeMutableRawBufferPointer(rebasing: target[(y * row)..<((y + 1) * row)]).copyMemory(from: from)
                    y += 1
                }
            }
            count = columns * rows
        }
    }

    /// The first pixel, in reading order, whose blue, green or red is above its alpha, or nil. Each row is read as
    /// little-endian words of a pixel each, alpha in the top byte, and a level above alpha makes alpha less that
    /// level wrap to a word with its top bit set; a row with such a word is read again for the first.
    static func fault(columns: Int, rows: Int, step: Int, _ source: UnsafeRawBufferPointer) -> (x: Int, y: Int)? {
        var y = 0
        while y < rows {
            var wrapped: UInt32 = 0
            var x = 0
            while x < columns {
                let word = UInt32(littleEndian: unsafe source.loadUnaligned(fromByteOffset: y * step + x * 4, as: UInt32.self))
                let alpha = word >> 24
                wrapped |= (alpha &- (word & 0xFF)) | (alpha &- (word >> 8 & 0xFF)) | (alpha &- (word >> 16 & 0xFF))
                x += 1
            }
            if wrapped & 0x8000_0000 != 0 {
                x = 0
                while x < columns {
                    let offset = y * step + x * 4
                    let alpha = unsafe source[offset + 3]
                    if unsafe source[offset] > alpha || source[offset + 1] > alpha || source[offset + 2] > alpha { return (x, y) }
                    x += 1
                }
            }
            y += 1
        }
        return nil
    }

    /// The pixels as bytes, blue, green, red, alpha, `width * 4` bytes a row, no padding.
    public var bytes: [UInt8] { pixels.withUnsafeBytes { unsafe [UInt8]($0) } }

    /// Peak signal-to-noise ratio in dB over the colour channels, alpha aside; equal pictures give +∞,
    /// and pictures of different sizes, which PSNR cannot compare, give `nil`.
    public func psnr(against other: Self) -> Double? {
        psnr(against: other, peak: 255) { p, q in
            let (blue, green, red) = (Int(p.blue) - Int(q.blue), Int(p.green) - Int(q.green), Int(p.red) - Int(q.red))
            return Double(blue * blue + green * green + red * red) / 3
        }
    }
}
