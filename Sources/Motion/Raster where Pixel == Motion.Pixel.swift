import Numeric
public import Raster

/// A frame's picture is a `Raster<Motion.Pixel>`: BGRA8 pixels, premultiplied, in sRGB, stored packed.
extension Raster where Pixel == Motion.Pixel {
    /// Reads `height` rows of `width` pixels from bytes in blue, green, red, alpha order, rows `stride` bytes apart.
    /// Row padding is dropped. Without a `stride` the rows are packed, `width × 4` bytes apart.
    public init(width: Cardinal, height: Cardinal, stride: Cardinal? = nil, bytes: [UInt8]) throws(Motion.Pixel.Error) {
        guard let columns = Int(exactly: width), let rows = Int(exactly: height) else { throw .overflow }
        let (row, wide) = columns.multipliedReportingOverflow(by: 4)
        guard !wide else { throw .overflow }
        guard let step = stride.map({ Int(exactly: $0) }) ?? row else { throw .overflow }
        guard step >= row else { throw .stride(Cardinal(UInt(step)), needed: Cardinal(UInt(row))) }
        let (needed, long) = step.multipliedReportingOverflow(by: rows)
        guard !long else { throw .overflow }
        guard bytes.count == needed else { throw .size(Cardinal(UInt(bytes.count)), needed: Cardinal(UInt(needed))) }
        let pixels = try Self.pixels(columns: columns, rows: rows, step: step, bytes: bytes)
        do throws(Raster<Motion.Pixel>.Error) {
            try self.init(width: width, height: height, pixels: pixels)
        } catch {
            throw .overflow
        }
    }

    /// The pixels of `rows` rows of `columns` pixels, rows `step` bytes apart; the sizes are already checked.
    /// A pixel is its four bytes in the order they are read, so each row is checked and then copied whole.
    /// Rows of no pixels hold nothing to read, however many bytes lie between them.
    static func pixels(columns: Int, rows: Int, step: Int, bytes: [UInt8]) throws(Motion.Pixel.Error) -> [Motion.Pixel] {
        guard columns > 0 else { return [] }
        let fault = bytes.withUnsafeBufferPointer { source -> (x: Int, y: Int)? in
            var (x, y) = (0, 0)
            while y < rows {
                let offset = y * step + x * 4
                let alpha = unsafe source[offset + 3]
                if unsafe source[offset] > alpha || source[offset + 1] > alpha || source[offset + 2] > alpha { return (x, y) }
                x += 1
                if x == columns { (x, y) = (0, y + 1) }
            }
            return nil
        }
        if let fault { throw .premultiplied(x: Ordinal(UInt(fault.x)), y: Ordinal(UInt(fault.y))) }
        return unsafe [Motion.Pixel](unsafeUninitializedCapacity: columns * rows) { pixels, count in
            bytes.withUnsafeBytes { source in
                var y = 0
                while y < rows {
                    let row = unsafe UnsafeRawBufferPointer(rebasing: source[(y * step)..<(y * step + columns * 4)])
                    let into = unsafe UnsafeMutableRawBufferPointer(rebasing: UnsafeMutableRawBufferPointer(pixels)[(y * columns * 4)..<((y + 1) * columns * 4)])
                    unsafe into.copyMemory(from: row)
                    y += 1
                }
            }
            count = columns * rows
        }
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
