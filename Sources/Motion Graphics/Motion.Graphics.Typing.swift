#if Graphics
    public import Motion
    public import Picture
    public import Timeline

    extension Motion.Graphics {
        /// A hand typing glyphs: the instant each key is struck, a `Timeline.Series` of swift-timeline, at uneven
        /// intervals between a first and a last stroke, by `Timeline.instants(_:from:to:weights:)`.
        ///
        /// The weights are the intervals' proportions, one for each interval after the first stroke: a caller's
        /// random numbers, longer before a new word, give a typist's rhythm, and the first and last strokes still
        /// fall exactly on the instants given.
        public struct Typing: Sendable, Hashable {
            /// The instants of the strokes, in order.
            public let series: Timeline.Series

            public init(_ count: Cardinal, from start: Rational, to end: Rational, weights: some Swift.Sequence<Rational>) {
                self.series = Timeline.Series(count, from: start, to: end, weights: weights)
            }
        }
    }

    extension Motion.Graphics.Typing {
        /// A hand typing a text in a cadence: one stroke for each glyph the text is set as, `Typesetting.Text.length(of:)`
        /// of them, the first at `start` and the last at `end`, the gaps between weighted by the cadence's
        /// `Timeline.Jitter` under a key. The instants are a pure function of the text, the key, the cadence and
        /// the two ends, so two runs with one key type alike, and never go back. A cadence's spread outside 0…1
        /// traps, as the jitter's does.
        public init(_ text: some Swift.StringProtocol, key: Threefry.Key, cadence: Cadence, from start: Rational, to end: Rational) {
            var glyphs: [[UInt8]] = []
            for byte in text.utf8 where byte != 0x0a {
                if byte & 0xc0 == 0x80, let last = glyphs.indices.last { glyphs[last].append(byte) } else { glyphs.append([byte]) }
            }
            let jitter = Timeline.Jitter(key: key, spread: cadence.spread)
            let weights = glyphs.indices.dropFirst().map { cadence.weight(of: glyphs, at: $0, jitter: jitter) }
            self.init(Cardinal(UInt(glyphs.count)), from: start, to: end, weights: weights)
        }
    }

    extension Motion.Graphics.Typing {
        /// The instant of each stroke, in order.
        public var strokes: [Rational] {
            series.instants
        }

        /// How many glyphs stand at an instant: the strokes at or before it, the series' `count(at:)`.
        public func standing(at instant: Rational) -> Cardinal {
            series.count(at: instant)
        }

        /// The share of the glyphs standing at an instant, 0 to 1, as `Motion.Graphics.Transcript.Line.Moment`
        /// takes it; with nothing to type, 1.
        public func share(at instant: Rational) -> Double {
            guard !strokes.isEmpty else { return 1 }
            return Double(Int(clamping: standing(at: instant))) / Double(strokes.count)
        }

        /// Whether a caret is lit at an instant: lit while the hand types, from the first stroke to the last,
        /// and otherwise lit for one `blink` and dark for the next, a loop of two blinks counted from instant zero
        /// before the first stroke and from the last stroke after it. With no blink it is always lit.
        public func lit(at instant: Rational, blink: Rational) -> Bool {
            guard blink > .zero else { return true }
            let since: Rational
            if let first = strokes.first, let last = strokes.last, instant >= first {
                guard instant >= last else { return true }
                since = instant - last
            } else {
                since = Swift.max(instant, .zero)
            }
            do throws(Timeline.Loop.Error) {
                return try Timeline.Loop(period: blink + blink).time(at: since) < blink
            } catch {
                return true
            }
        }
    }
#endif
