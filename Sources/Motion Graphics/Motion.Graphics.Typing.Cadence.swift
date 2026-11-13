#if Graphics
    public import Motion
    import Picture

    extension Motion.Graphics.Typing {
        /// A typist's rhythm: how uneven the gaps between strokes are, and how much longer or shorter the gap is
        /// before a word's first key and before a space.
        ///
        /// Each gap's weight is a draw `u` from [0, 1), taken down to a multiple of 1/1024, as `1 + spread × (2u − 1)`, times `word`
        /// when the key struck begins a word (the character before it is a space) and times `space` when the key
        /// is a space. The weights are proportions, so only their ratios matter.
        public struct Cadence: Sendable, Hashable {
            /// How far a gap may stray from a plain one either way, as a share of it: 0 for even gaps, 1/2 for gaps
            /// from half a plain gap to one and a half.
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
        /// The weight of the gap before the character at a position after the first, under a key: the draw is
        /// `Threefry.unit(key:stream:index:)` of the key at stream 0 and the position as index.
        func weight(of characters: [Character], at position: Int, key: Threefry.Key) -> Rational {
            let drawn = Threefry.unit(key: key, stream: 0, index: UInt64(position), as: Double.self)
            let steps = Swift.min(Int((drawn * 1024).rounded(.down)), 1023)
            var weight: Rational
            do throws(Rational.Error) {
                weight = Rational(1) + spread * (try Rational(numerator: 2 * steps - 1024, denominator: 1024))
            } catch {
                preconditionFailure("1024 is not zero")
            }
            if characters[position - 1] == " " { weight = weight * word }
            if characters[position] == " " { weight = weight * space }
            return weight
        }
    }
#endif
