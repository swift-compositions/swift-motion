#if Picture
    public import Byte
    public import Motion
    public import Picture

    extension Motion.Pairs {
        /// How a pair's instant is written above it: in a font the caller gives, at a size, in a colour, through
        /// swift-picture's `Picture.Text`. This package bundles no font.
        public struct Label: Sendable, Hashable {
            /// The bytes of a TrueType or OpenType font file.
            public var font: [Byte]

            /// The text's size in pixels: an em.
            public var size: Double

            /// The text's colour.
            public var color: Picture::Picture.Color

            public init(font: [Byte], size: Double = 16, color: Picture::Picture.Color = .white) {
                self.font = font
                self.size = size
                self.color = color
            }
        }
    }

    extension Motion.Pairs.Label {
        /// The height of a label's row: the size and a quarter, rounded up.
        var height: Cardinal {
            Cardinal(UInt(Swift.max((size * 1.25).rounded(.up), 0)))
        }

        /// An instant in seconds with two decimals, the hundredths rounded to the nearest, halves up: `12.50 s`.
        /// An instant before zero, or of more hundredths than a signed word holds, is written as zero.
        public static func text(_ instant: Rational) -> Swift.String {
            let doubled = (instant * Rational(200) + Rational.one).floor.exactly(Int.self) ?? 0
            let whole = (Swift.max(doubled, 0) / 2).quotientAndRemainder(dividingBy: 100)
            let digits = Swift.String(whole.remainder)
            return Swift.String(whole.quotient) + "." + (digits.count < 2 ? "0" + digits : digits) + " s"
        }

        /// The label of an instant: its text set in the font, its first baseline an eighth of the size below the
        /// row's top plus the font's ascent, starting an eighth of the size from the left.
        func picture(of instant: Rational) throws(Motion.Pairs.Error) -> Picture::Picture {
            let set: Picture::Picture.Text
            do throws(Picture::Picture.Text.Error) {
                set = try Picture::Picture.Text(Self.text(instant), bytes: font, size: size)
            } catch {
                throw .label(error)
            }
            let inset = size / 8
            return Picture::Picture([set.placed(.init(.solid(color)), at: .init([inset, inset + set.ascent]))])
        }
    }
#endif
