import Numeric
public import Raster

/// A frame's picture is a `Raster<Motion.Pixel>`: BGRA8 pixels, premultiplied, in sRGB, stored packed.
extension Raster where Pixel == Motion.Pixel {
    /// Reads `height` rows of `width` pixels from bytes in blue, green, red, alpha order, rows `stride` bytes apart.
    /// Row padding is dropped.
    public init(width: Int, height: Int, stride: Int? = nil, bytes: [UInt8]) throws(Motion.Pixel.Error) {
        let stride = stride ?? width * 4
        guard width >= 0, height >= 0 else { throw .size(bytes.count, needed: 0) }
        guard stride >= width * 4 else { throw .stride(stride, needed: width * 4) }
        guard bytes.count == stride * height else { throw .size(bytes.count, needed: stride * height) }
        var pixels: [Motion.Pixel] = []
        pixels.reserveCapacity(width * height)
        for index in 0..<(width * height) {
            let (x, y) = (index % width, index / width)
            let offset = y * stride + x * 4
            guard let pixel = Motion.Pixel(blue: bytes[offset], green: bytes[offset + 1], red: bytes[offset + 2], alpha: bytes[offset + 3]) else {
                throw .premultiplied(x: x, y: y)
            }
            pixels.append(pixel)
        }
        do throws(Raster<Motion.Pixel>.Error) {
            try self.init(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), pixels: pixels)
        } catch {
            throw .size(bytes.count, needed: stride * height)
        }
    }

    /// The pixels as bytes, blue, green, red, alpha, `width * 4` bytes a row, no padding.
    public var bytes: [UInt8] { pixels.flatMap { [$0.blue, $0.green, $0.red, $0.alpha] } }

    /// Peak signal-to-noise ratio in dB over the colour channels, alpha aside; equal pictures give +∞,
    /// and pictures of different sizes, which PSNR cannot compare, give `nil`.
    public func psnr(against other: Self) -> Double? {
        psnr(against: other, peak: 255) { p, q in
            let (blue, green, red) = (Int(p.blue) - Int(q.blue), Int(p.green) - Int(q.green), Int(p.red) - Int(q.red))
            return Double(blue * blue + green * green + red * red) / 3
        }
    }
}
