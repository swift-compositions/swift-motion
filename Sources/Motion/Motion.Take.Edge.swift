extension Motion.Take {
    /// What a take shows at an instant outside its frames, before zero or from the end of the last frame on.
    ///
    /// The names are those of `Raster.Edge` for a pixel outside a raster: `extend` gives the nearest one.
    public enum Edge: Sendable, Hashable, CaseIterable {
        /// No frame: the take shows nothing there.
        case empty

        /// The nearest frame, held: the first before zero and the last from the end of the last frame on.
        case extend
    }
}
