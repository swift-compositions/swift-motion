import AVFoundation
public import Motion

extension Motion.Encoding {
    /// A size a movie is made smaller to for sharing: the largest picture of the preset's shape it fits within.
    public enum Preset: Swift.String, Sendable, Hashable, CaseIterable {
        /// Within 960 × 540.
        case height540 = "540"

        /// Within 1280 × 720.
        case height720 = "720"

        /// Within 1920 × 1080.
        case height1080 = "1080"
    }
}

extension Motion.Encoding.Preset {
    /// AVFoundation's name for the export preset.
    var name: Swift.String {
        switch self {
        case .height540: AVAssetExportPreset960x540

        case .height720: AVAssetExportPreset1280x720

        case .height1080: AVAssetExportPreset1920x1080
        }
    }
}
