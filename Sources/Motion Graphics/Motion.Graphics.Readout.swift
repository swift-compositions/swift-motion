#if Graphics
    import Formatter
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A small heads-up readout on a plate: a label, a count in tabular figures padded with zeros to as many
        /// digits as its total, the total after a word between them, and a bar under them that the count's share
        /// of the total fills.
        public struct Readout: Sendable {
            public var label: Swift.String

            /// The word between the count and the total, such as `/ `.
            public var of: Swift.String
            public var value: Cardinal
            public var total: Cardinal

            /// A point of the plate's top edge: its left end, its middle or its right end, as `anchor` says.
            public var place: Picture.Plane.Point<2>
            public var anchor: Picture.Text.Alignment
            public var style: Style

            public init(
                _ label: Swift.String,
                value: Cardinal,
                of: Swift.String,
                total: Cardinal,
                at place: Picture.Plane.Point<2>,
                anchor: Picture.Text.Alignment,
                style: Style
            ) {
                self.label = label
                self.value = value
                self.of = of
                self.total = total
                self.place = place
                self.anchor = anchor
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Readout {
        /// The count as written: its digits, padded with zeros to as many as the total has.
        public var figures: Swift.String {
            let digits = Formatter.Number().format(Double(Int(clamping: total))).count
            return Formatter.Number(padding: Cardinal(UInt(digits))).format(Double(Int(clamping: value)))
        }

        /// The whole line: the label, a space, the count, a space, the word and the total, each digit tabular.
        var line: Swift.String {
            label + " " + figures + " " + rest
        }

        /// The word and the total.
        var rest: Swift.String {
            of + Formatter.Number().format(Double(Int(clamping: total)))
        }

        /// The share of the total the count has come to, 0 to 1; a total of nothing is full.
        public var share: Double {
            let total = Double(Int(clamping: total))
            guard total > 0 else { return 1 }
            return Swift.min(Double(Int(clamping: value)) / total, 1)
        }
    }
#endif
