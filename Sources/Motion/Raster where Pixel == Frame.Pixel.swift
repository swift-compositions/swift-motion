import ISO_9899
public import Raster

/// A frame's picture is a `Raster<Frame.Pixel>`: BGRA8 pixels, premultiplied, in sRGB, stored packed.
extension Raster where Pixel == Frame.Pixel {
    /// Reads `height` rows of `width` pixels from bytes in blue, green, red, alpha order, rows `stride` bytes apart.
    /// Row padding is dropped.
    public init(width: Int, height: Int, stride: Int? = nil, bytes: [UInt8]) throws(Frame.Pixel.Error) {
        let stride = stride ?? width * 4
        guard width >= 0, height >= 0 else { throw .size(bytes.count, needed: 0) }
        guard stride >= width * 4 else { throw .stride(stride, needed: width * 4) }
        guard bytes.count == stride * height else { throw .size(bytes.count, needed: stride * height) }
        var pixels: [Frame.Pixel] = []
        pixels.reserveCapacity(width * height)
        for index in 0..<(width * height) {
            let (x, y) = (index % width, index / width)
            let offset = y * stride + x * 4
            guard let pixel = Frame.Pixel(blue: bytes[offset], green: bytes[offset + 1], red: bytes[offset + 2], alpha: bytes[offset + 3]) else {
                throw .premultiplied(x: x, y: y)
            }
            pixels.append(pixel)
        }
        do throws(Raster<Frame.Pixel>.Error) {
            try self.init(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), pixels: pixels)
        } catch {
            throw .size(bytes.count, needed: stride * height)
        }
    }

    /// The pixels as bytes, blue, green, red, alpha, `width * 4` bytes a row, no padding.
    public var bytes: [UInt8] { pixels.flatMap { [$0.blue, $0.green, $0.red, $0.alpha] } }

    /// The top `rows` rows.
    public func top(_ rows: Int) -> Self {
        precondition(rows >= 0 && rows <= Int(bitPattern: height), "a raster's top rows are within it")
        do throws(Raster<Frame.Pixel>.Error) {
            return try cropped(to: Region(x: 0, y: 0, width: width, height: Cardinal(UInt(rows))))
        } catch {
            preconditionFailure("checked above")
        }
    }

    /// Peak signal-to-noise ratio in dB over the colour channels, alpha aside; equal pictures give +∞,
    /// and pictures of different sizes, which PSNR cannot compare, give `nil`.
    public static func psnr(_ a: Self, _ b: Self) -> Double? {
        let squares = a.zip(b) { p, q in
            let (blue, green, red) = (Int(p.blue) - Int(q.blue), Int(p.green) - Int(q.green), Int(p.red) - Int(q.red))
            return blue * blue + green * green + red * red
        }
        guard let squares else { return nil }
        let sum = Double(squares.reduce(0, +))
        guard sum > 0 else { return .infinity }
        let mse = sum / Double(a.pixels.count * 3)
        return 10 * ISO_9899.Math.log10(255 * 255 / mse)
    }
}
