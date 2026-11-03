extension Render {
    public enum Verdict: Hashable, Sendable {
        case deterministic
        case varies(frame: Int, psnr: Double)
    }
}
