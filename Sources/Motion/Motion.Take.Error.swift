extension Motion.Take {
    /// Why frames make no take, or a take's written form or one of its frames cannot be read.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The frame at this position is not the size of the first.
        case size(Ordinal)

        /// The rate's numerator or denominator, in lowest terms, does not fit 64 bits, so the take is not written.
        case rate

        /// The bytes are not a take's written form: they do not begin with its signature.
        case foreign

        /// The bytes are a take's written form in a version this package does not read.
        case version(UInt32)

        /// The bytes end before the parts their head and index name: a file cut short.
        case truncated

        /// The head or the index fails its check, or names frames that are not among the bytes.
        case index

        /// The frame at this position does not inflate to pixels of the take's size whose digest is the one its
        /// index gives.
        case damaged(Ordinal)

        /// The bytes could not be read, for the reason given by what reads them.
        case unreadable(Swift.String)
    }
}
