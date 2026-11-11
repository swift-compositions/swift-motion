public import Rate

/// The frame rates video is made at, in frames per second.
extension Rate {
    /// 24000/1001, film carried in NTSC video.
    public static let film = Self.frames(24000, per: 1001)
    /// 30000/1001, NTSC video.
    public static let ntsc = Self.frames(30000, per: 1001)
    /// 30 exactly.
    public static let thirty = Self.frames(30, per: 1)

    private static func frames(_ count: Integer, per seconds: Integer) -> Self {
        do throws(Rate.Error) {
            return try Self(count, per: seconds)
        } catch {
            preconditionFailure("a positive count over positive seconds is a rate")
        }
    }
}
