/// The render contract: a frame's picture depends on its time alone.
public enum Render {}

extension Render {
    /// Renders each frame twice and reports the first that differs, with its PSNR, or that its size changed.
    public static func check(_ frames: some Swift.Sequence<Int>, render: (Int) -> Raster) -> Verdict {
        for frame in frames {
            let (first, second) = (render(frame), render(frame))
            guard first != second else { continue }
            guard let psnr = Raster.psnr(first, second) else { return .resized(frame: frame) }
            return .varies(frame: frame, psnr: psnr)
        }
        return .deterministic
    }
}
