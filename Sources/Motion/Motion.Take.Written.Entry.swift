public import FIPS_180_4

extension Motion.Take.Written {
    /// A frame's line in the index: where its compressed pixels begin, how many bytes they are, and its digest.
    struct Entry: Sendable {
        let offset: UInt64
        let length: UInt64
        let digest: FIPS_180_4.Digest
    }
}
