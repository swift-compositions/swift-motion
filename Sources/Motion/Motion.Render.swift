public import Raster

extension Motion {
    /// The render contract: a frame's picture depends on its time alone.
    public enum Render {}
}

extension Motion.Render {
    /// Renders each frame twice and reports the first that differs, with its PSNR, or that its size changed.
    public static func check(_ frames: some Swift.Sequence<Ordinal>, render: (Ordinal) -> Raster<Motion.Pixel>) -> Verdict {
        for frame in frames {
            let (first, second) = (render(frame), render(frame))
            guard first != second else { continue }
            guard let psnr = first.psnr(against: second) else { return .resized(frame: frame) }
            return .varies(frame: frame, psnr: psnr)
        }
        return .deterministic
    }

    /// The same check over the first `count` frames, from frame zero.
    public static func check(first count: Cardinal, render: (Ordinal) -> Raster<Motion.Pixel>) -> Verdict {
        check((0..<count.rawValue).lazy.map(Ordinal.init), render: render)
    }
}
