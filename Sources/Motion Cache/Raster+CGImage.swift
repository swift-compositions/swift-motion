public import CoreGraphics
public import Motion

extension Raster {
    /// The image's pixels in sRGB, BGRA8 premultiplied, packed.
    public init?(image: CGImage) {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let drawn = bytes.withUnsafeMutableBytes { memory in
            guard
                let context = unsafe CGContext(
                    data: memory.baseAddress,
                    width: image.width,
                    height: image.height,
                    bitsPerComponent: 8,
                    bytesPerRow: image.width * 4,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                )
            else { return false }
            context.interpolationQuality = .none
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { return nil }
        do throws(Raster.Error) {
            try self.init(width: image.width, height: image.height, bytes: bytes)
        } catch {
            return nil
        }
    }
}
