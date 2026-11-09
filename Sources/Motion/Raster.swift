/// A picture: `height` rows of `width` BGRA8 pixels, premultiplied, in sRGB, `stride` bytes apart.
///
/// No colour channel exceeds its alpha, and two rasters are equal when their pixels are,
/// whatever padding their rows carry.
import ISO_9899

public struct Raster: Sendable {
    public let width: Int
    public let height: Int
    public let stride: Int
    public let bytes: [UInt8]
}

extension Raster {
    public init(width: Int, height: Int, stride: Int? = nil, bytes: [UInt8]) throws(Raster.Error) {
        let stride = stride ?? width * 4
        guard stride >= width * 4 else { throw .stride(stride, needed: width * 4) }
        guard bytes.count == stride * height else { throw .size(bytes.count, needed: stride * height) }
        if let offset = Self.firstOver(bytes, width: width, height: height, stride: stride) {
            throw .premultiplied(x: offset % stride / 4, y: offset / stride)
        }
        self.width = width
        self.height = height
        self.stride = stride
        self.bytes = bytes
    }

    /// The offset of the first pixel with a colour channel above its alpha.
    static func firstOver(_ bytes: [UInt8], width: Int, height: Int, stride: Int) -> Int? {
        bytes.withUnsafeBufferPointer { buffer in
            for y in 0..<height {
                let row = y * stride
                for offset in Swift.stride(from: row, to: row + width * 4, by: 4) {
                    let alpha = unsafe buffer[offset + 3]
                    if unsafe buffer[offset] > alpha || buffer[offset + 1] > alpha || buffer[offset + 2] > alpha { return offset }
                }
            }
            return nil
        }
    }

    /// The top `rows` rows. A part of a valid raster is valid, so it is not checked again.
    public func top(_ rows: Int) -> Raster {
        precondition(rows >= 0 && rows <= height, "a raster's top rows are within it")
        return Raster(width: width, height: rows, stride: stride, valid: Array(bytes[0..<rows * stride]))
    }

    init(width: Int, height: Int, stride: Int, valid bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.stride = stride
        self.bytes = bytes
    }

    /// Row `y`'s pixels, without its padding.
    public func row(_ y: Int) -> ArraySlice<UInt8> { bytes[y * stride..<y * stride + width * 4] }

    /// The pixels packed without padding, `width * 4` bytes a row.
    public var packed: [UInt8] { stride == width * 4 ? bytes : (0..<height).flatMap { row($0) } }
}

extension Raster: Equatable {
    public static func == (a: Self, b: Self) -> Bool {
        a.width == b.width && a.height == b.height && (0..<a.height).allSatisfy { a.row($0) == b.row($0) }
    }
}

extension Raster {
    /// Peak signal-to-noise ratio in dB over the colour channels, alpha aside; equal pictures give +∞,
    /// and pictures of different sizes, which PSNR cannot compare, give `nil`.
    public static func psnr(_ a: Self, _ b: Self) -> Double? {
        guard a.width == b.width && a.height == b.height else { return nil }
        var sum = 0.0
        (0..<a.height).forEach { y in
            for (k, (p, q)) in zip(a.row(y), b.row(y)).enumerated() where k % 4 != 3 {
                let d = Double(Int(p) - Int(q))
                sum += d * d
            }
        }
        guard sum > 0 else { return .infinity }
        let mse = sum / Double(a.width * a.height * 3)
        return 10 * ISO_9899.Math.log10(255 * 255 / mse)
    }
}
