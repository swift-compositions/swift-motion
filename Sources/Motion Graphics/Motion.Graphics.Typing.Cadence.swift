#if Graphics
    public import Motion
    import Timeline

    extension Motion.Graphics.Typing {
        /// A typist's rhythm: how uneven the gaps between strokes are, and how much longer or shorter the gap is
        /// before a word's first key and before a space.
        ///
        /// The gap before the glyph at position i is the weight of a `Timeline.Jitter` of the spread at i,
        /// `1 + spread × (2s − 1024) / 1024` for s the top ten bits of the key's Threefry block at i in stream 0,
        /// times `word` when the key struck begins a word (the glyph before it is a space) and times `space` when
        /// it is a space. The weights are proportions, so only their ratios matter.
        public struct Cadence: Sendable, Hashable {
            /// How far a gap may stray from a plain one either way, as a share of it, from 0 to 1: 0 for even
            /// gaps, 1/2 for gaps from half a plain gap to one and a half.
            public var spread: Rational

            /// The gap before a word's first key, as a multiple of a plain gap.
            public var word: Rational

            /// The gap before a space, as a multiple of a plain gap.
            public var space: Rational

            public init(spread: Rational, word: Rational, space: Rational) {
                self.spread = spread
                self.word = word
                self.space = space
            }
        }
    }

    extension Motion.Graphics.Typing.Cadence {
        /// The weight of the gap before the glyph at a position after the first, each glyph its bytes in UTF-8:
        /// the jitter's weight at the position, times the word's before a word and the space's before a space.
        func weight(of glyphs: [[UInt8]], at position: Int, jitter: Timeline.Jitter) -> Rational {
            var weight = jitter.weight(at: UInt64(position))
            if glyphs[position - 1] == [0x20] { weight *= word }
            if glyphs[position] == [0x20] { weight *= space }
            return weight
        }
    }
#endif
