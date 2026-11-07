import ISO_9899

extension Raster {
    /// Peak signal-to-noise ratio in dB over the colour channels, alpha aside; equal pictures give +∞.
    public static func psnr(_ a: Self, _ b: Self) -> Double {
        precondition(a.width == b.width && a.height == b.height, "PSNR compares pictures of one size")
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
