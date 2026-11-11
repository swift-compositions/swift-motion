public import Raster

extension Motion {
    /// The render contract: a frame's picture depends on its time alone.
    public enum Render {}
}

extension Motion.Render {
    /// Renders each frame twice and reports the first that differs, with its PSNR, or that its size changed.
    public static func check(_ frames: some Swift.Sequence<Ordinal>, render: (Ordinal) -> Raster<Motion.Pixel>) -> Verdict {
        for frame in frames {
            if let verdict = differing(frame, render: render) { return verdict }
        }
        return .deterministic
    }

    /// How `frame` differs between two renders, or nil when both are the same.
    static func differing(_ frame: Ordinal, render: (Ordinal) -> Raster<Motion.Pixel>) -> Verdict? {
        let (first, second) = (render(frame), render(frame))
        guard first != second else { return nil }
        guard let psnr = first.psnr(against: second) else { return .resized(frame: frame) }
        return .varies(frame: frame, psnr: psnr)
    }

    /// The same check over the first `count` frames, from frame zero.
    public static func check(first count: Cardinal, render: (Ordinal) -> Raster<Motion.Pixel>) -> Verdict {
        var frame = Ordinal.zero
        while frame < Ordinal(count) {
            if let verdict = differing(frame, render: render) { return verdict }
            frame += Cardinal.one
        }
        return .deterministic
    }
}
