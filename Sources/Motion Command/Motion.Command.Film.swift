#if Command
    public import Motion
    public import Motion_Picture

    extension Motion.Command {
        /// What a film's command line writes from: the reel, proofs of its parts by key, and proofs of the whole
        /// reel by name, whose frames are counted from the reel's start.
        public struct Film<Key: Hashable & Sendable>: Sendable {
            public var reel: Motion.Reel<Key>
            /// Proofs of the parts with a key, used in place of their overviews.
            public var parts: [Key: Motion.Reel<Key>.Proof]
            /// Proofs of the whole reel, by name: of a layer's span, say, through `Motion.Reel.positions(ofLayer:)`.
            public var proofs: [Swift.String: Motion.Reel<Key>.Proof]

            public init(
                _ reel: Motion.Reel<Key>,
                parts: [Key: Motion.Reel<Key>.Proof] = [:],
                proofs: [Swift.String: Motion.Reel<Key>.Proof] = [:]
            ) {
                self.reel = reel
                self.parts = parts
                self.proofs = proofs
            }
        }
    }
#endif
