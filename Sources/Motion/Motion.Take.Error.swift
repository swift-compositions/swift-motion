extension Motion.Take {
    /// Why frames make no take.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The frame at this position is not the size of the first.
        case size(Ordinal)
    }
}
