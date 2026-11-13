#if Graphics
    public import Motion
    import Timeline

    extension Motion.Graphics {
        /// A hand typing characters: the instant each key is struck, at uneven intervals between a first and a
        /// last stroke, by `Timeline.instants(_:from:to:weights:)`.
        ///
        /// The weights are the intervals' proportions, one for each interval after the first stroke: a caller's
        /// random numbers, longer before a new word, give a typist's rhythm, and the first and last strokes still
        /// fall exactly on the instants given.
        public struct Typing: Sendable, Hashable {
            /// The instant of each stroke, in order.
            public let strokes: [Rational]

            public init(_ count: Cardinal, from start: Rational, to end: Rational, weights: some Swift.Sequence<Rational>) {
                self.strokes = Timeline.instants(count, from: start, to: end, weights: weights)
            }
        }
    }

    extension Motion.Graphics.Typing {
        /// How many characters stand at an instant: the strokes at or before it.
        public func standing(at instant: Rational) -> Cardinal {
            Cardinal(UInt(strokes.prefix { $0 <= instant }.count))
        }

        /// The share of the characters standing at an instant, 0 to 1, as `Motion.Graphics.Transcript.Line.Moment`
        /// takes it; with nothing to type, 1.
        public func share(at instant: Rational) -> Double {
            guard !strokes.isEmpty else { return 1 }
            return Double(Int(clamping: standing(at: instant))) / Double(strokes.count)
        }

        /// Whether a caret is lit at an instant: lit while the hand types, from the first stroke to the last,
        /// and otherwise lit for one `blink` and dark for the next, counted from instant zero before the first
        /// stroke and from the last stroke after it. With no blink it is always lit.
        public func lit(at instant: Rational, blink: Rational) -> Bool {
            guard blink > .zero else { return true }
            let since: Rational
            if let first = strokes.first, let last = strokes.last, instant >= first {
                guard instant >= last else { return true }
                since = instant - last
            } else {
                since = Swift.max(instant, .zero)
            }
            do throws(Rational.Error) {
                let blinks = try since.divided(by: blink).floor.exactly(Int.self) ?? 0
                return blinks.isMultiple(of: 2)
            } catch {
                return true
            }
        }
    }
#endif
