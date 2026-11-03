/// A picture: `height` rows of `width` BGRA8 pixels, premultiplied, in sRGB, `stride` bytes apart.
///
/// No colour channel exceeds its alpha, and two rasters are equal when their pixels are,
/// whatever padding their rows carry.
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
        for y in 0..<height {
            for x in 0..<width where Self.over(bytes, at: y * stride + x * 4) {
                throw .premultiplied(x: x, y: y)
            }
        }
        self.width = width
        self.height = height
        self.stride = stride
        self.bytes = bytes
    }

    static func over(_ bytes: [UInt8], at offset: Int) -> Bool {
        let alpha = bytes[offset + 3]
        return bytes[offset] > alpha || bytes[offset + 1] > alpha || bytes[offset + 2] > alpha
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
