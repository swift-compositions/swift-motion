#if Graphics
    import Formatter
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A small heads-up readout on a plate: a label, a count in tabular figures padded with zeros to as many
        /// digits as its total, the total after a word between them, and a bar under them that the count's share
        /// of the total fills.
        ///
        /// The line is set once, when the readout is made, with the count's place as wide as the total's digits;
        /// the count itself is its moment's, laid digit by digit from the ten digits set in the same figures, so
        /// a readout that counts sets no type as it counts.
        public struct Readout: Sendable {
            public let label: Swift.String
            /// The word between the count and the total, such as `/ `.
            public let word: Swift.String
            public let total: Cardinal
            /// A point of the plate's top edge: its left end, its middle or its right end, as `anchor` says.
            public var place: Picture.Plane.Point<2>
            public var anchor: Picture.Text.Alignment
            public let style: Style
            /// The whole line, the count's place filled with zeros.
            let line: Picture.Text
            /// The label, and the word and the total, each set alone.
            let opening: Picture.Text
            let closing: Picture.Text
            /// The outline of each digit, 0 to 9, about its own origin.
            let digits: [Picture.Plane.Path]
            /// The origin of each of the count's digits, from the count's start.
            let origins: [Double]

            /// A readout, its line set once: it fails as `Picture.Text` does for the line in the ink's font at its
            /// size. Its figures give every digit one advance: proportional figures are set tabular.
            public init(
                _ label: Swift.String,
                of word: Swift.String,
                total: Cardinal,
                at place: Picture.Plane.Point<2>,
                anchor: Picture.Text.Alignment,
                style: Style
            ) throws(Picture.Text.Error) {
                self.label = label
                self.word = word
                self.total = total
                self.place = place
                self.anchor = anchor
                self.style = style
                let ink = style.ink
                let figures = style.figures == .proportional ? .tabular : style.figures
                let zeros = Self.figures(of: .zero, total: total)
                let closing = word + Formatter.Number().format(Double(Int(clamping: total)))
                self.line = try ink.text(label + " " + zeros + " " + closing, figures: figures)
                self.opening = try ink.text(label, figures: figures)
                self.closing = try ink.text(closing, figures: figures)
                self.digits = try ink.text("0123456789", figures: figures).glyphs.map(\.outline)
                self.origins = try ink.text(zeros, figures: figures).glyphs.map { $0.origin[0] }
            }
        }
    }

    extension Motion.Graphics.Readout {
        /// A count as written: its digits, padded with zeros to as many as the total has, a count above the total
        /// read as the total.
        public func figures(of count: Cardinal) -> Swift.String {
            Self.figures(of: count, total: total)
        }

        static func figures(of count: Cardinal, total: Cardinal) -> Swift.String {
            let digits = Formatter.Number().format(Double(Int(clamping: total))).count
            return Formatter.Number(padding: Cardinal(UInt(digits))).format(Double(Int(clamping: Swift.min(count, total))))
        }

        /// A count's outline from the start of its place on the baseline: each digit's outline at its origin.
        func path(of count: Cardinal) -> Picture.Plane.Path {
            let written = figures(of: count).utf8.compactMap { byte in (0x30...0x39).contains(byte) ? Int(byte) - 0x30 : nil }
            return Picture.Plane.Path(
                subpaths: zip(written, origins).flatMap { digit, origin in
                    digits[digit].transformed(by: .translation(Vector([origin, 0.0]))).subpaths
                }
            )
        }

        /// The plate at rest, before the readout grows, turns or drops: as wide as the line and two insets,
        /// `height` tall, its top edge through `place` at its left end, its middle or its right end as
        /// `anchor` says. Since the count's digits share one advance, it is the same whatever the count reads.
        public var plate: Picture.Plane.Rectangle {
            let wide = line.width + 2 * style.inset
            let left = place[0] - anchor.indent(of: 0, in: wide)
            let top = place[1]
            return Picture.Plane.Rectangle(llx: .init(left), lly: .init(top), urx: .init(left + wide), ury: .init(top + style.height))
        }

        /// Where the readout stands at a moment: grown about the plate's middle from `1 − grow` of its size by how
        /// far it has shown, then turned by the tilt about the pivot and dropped. The plate at a moment is `plate`
        /// under this transform, and so is everything the readout draws.
        public func transform(at moment: Moment) -> Picture.Transform {
            let plate = plate
            let (left, top) = (plate.llx.underlying, plate.lly.underlying)
            let middle = Picture.Plane.Point<2>([(left + plate.urx.underlying) / 2, (top + plate.ury.underlying) / 2])
            let grown = Picture.Transform.scale(1 - style.grow + style.grow * moment.shown, about: middle)
            let pivot = Picture.Plane.Point<2>([left + style.pivot[0], top + style.pivot[1]])
            let turned = Picture.Transform.translation(x: 0, y: moment.drop).multiplied(by: .rotation(Radian(moment.tilt), about: pivot))
            return turned.multiplied(by: grown)
        }

        /// The share of the total a count has come to, 0 to 1; a total of nothing is full.
        public func share(of count: Cardinal) -> Double {
            let total = Double(Int(clamping: total))
            guard total > 0 else { return 1 }
            return Swift.min(Double(Int(clamping: count)) / total, 1)
        }
    }
#endif
