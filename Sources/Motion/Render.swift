/// The render contract: a frame's picture depends on its time alone.
public enum Render {}

extension Render {
    /// Renders each frame twice and reports the first that differs, with its PSNR.
    public static func check(_ frames: some Sequence<Int>, render: (Int) -> Raster) -> Verdict {
        for frame in frames {
            let (first, second) = (render(frame), render(frame))
            if first != second { return .varies(frame: frame, psnr: Raster.psnr(first, second)) }
        }
        return .deterministic
    }
}
