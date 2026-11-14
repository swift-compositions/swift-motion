public import CoreGraphics
import Foundation
public import Motion

extension Raster where Pixel == Motion.Pixel {
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
        guard let width = UInt(exactly: image.width), let height = UInt(exactly: image.height) else { return nil }
        do throws(Motion.Pixel.Error) {
            try self.init(width: Cardinal(width), height: Cardinal(height), bytes: bytes)
        } catch {
            return nil
        }
    }
}

extension Raster where Pixel == Motion.Pixel {
    /// The pixels as an sRGB image, BGRA8 premultiplied.
    public var image: CGImage? {
        guard
            let wide = Int(exactly: width),
            let tall = Int(exactly: height),
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let provider = CGDataProvider(data: pixels.withUnsafeBytes { unsafe Data($0) } as CFData)
        else { return nil }
        return unsafe CGImage(
            width: wide,
            height: tall,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: wide * 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
